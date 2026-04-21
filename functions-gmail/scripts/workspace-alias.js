#!/usr/bin/env node
'use strict';

const fs = require('fs');
const https = require('https');
const crypto = require('crypto');

const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
const adminUser = process.env.WORKSPACE_ADMIN_IMPERSONATE || 'info@licitago.es';
const targetUser = process.env.WORKSPACE_TARGET_USER || 'info@licitago.es';
const gmailImpersonateUser = process.env.WORKSPACE_GMAIL_IMPERSONATE || targetUser;
const aliasEmail = process.env.ASTRO_MAIL_ALIAS || 'publicidad@carta-astral-gratis.es';
const displayName = process.env.ASTRO_MAIL_DISPLAY_NAME || 'Astro Cluster';
const action = process.argv[2] || 'inspect';

const adminScopes = [
  'https://www.googleapis.com/auth/admin.directory.user',
  'https://www.googleapis.com/auth/admin.directory.user.readonly',
  'https://www.googleapis.com/auth/admin.directory.user.alias',
  'https://www.googleapis.com/auth/admin.directory.group',
  'https://www.googleapis.com/auth/admin.directory.group.readonly',
  'https://www.googleapis.com/auth/admin.directory.group.member',
];

const gmailScopes = [
  'https://www.googleapis.com/auth/gmail.settings.basic',
  'https://www.googleapis.com/auth/gmail.settings.sharing',
];

const groupSettingsScopes = [
  'https://www.googleapis.com/auth/apps.groups.settings',
];

function b64url(value) {
  return Buffer.from(value)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

function request(options, body) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          data = data ? JSON.parse(data) : {};
        } catch {
          // Keep non-JSON responses inspectable.
        }
        resolve({ status: res.statusCode, body: data });
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

async function accessToken(scopeList, subject) {
  if (!credentialsPath) {
    throw new Error('Falta GOOGLE_APPLICATION_CREDENTIALS');
  }
  const credentials = JSON.parse(fs.readFileSync(credentialsPath, 'utf8'));
  const now = Math.floor(Date.now() / 1000);
  const encodedHeader = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const encodedClaim = b64url(JSON.stringify({
    iss: credentials.client_email,
    scope: scopeList.join(' '),
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    sub: subject,
  }));
  const unsigned = `${encodedHeader}.${encodedClaim}`;
  const signer = crypto.createSign('RSA-SHA256');
  signer.update(unsigned);
  signer.end();

  const assertion = `${unsigned}.${b64url(signer.sign(credentials.private_key))}`;
  const body = new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion,
  }).toString();

  const res = await request({
    method: 'POST',
    hostname: 'oauth2.googleapis.com',
    path: '/token',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Content-Length': Buffer.byteLength(body),
    },
  }, body);

  if (res.status >= 400) {
    if (res.body?.error === 'access_denied') {
      throw new Error([
        'La service account no tiene autorizados los scopes DWD necesarios.',
        'Autoriza estos scopes en Google Admin > Seguridad > Control de API > Delegacion de todo el dominio:',
        [...adminScopes, ...gmailScopes, ...groupSettingsScopes].join(','),
      ].join('\n'));
    }
    throw new Error(`No se pudo obtener token DWD: ${JSON.stringify(res.body)}`);
  }
  return res.body.access_token;
}

async function api(token, method, hostname, path, payload) {
  const body = payload ? JSON.stringify(payload) : undefined;
  const res = await request({
    method,
    hostname,
    path,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/json',
      ...(body ? {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
      } : {}),
    },
  }, body);
  return res;
}

async function getJson(token, hostname, path) {
  return api(token, 'GET', hostname, path);
}

function summarizeError(res) {
  return res.body?.error?.message || res.body?.error || res.body;
}

async function inspect(adminToken, gmailToken) {
  const adminPaths = [
    ['targetUser', 'admin.googleapis.com', `/admin/directory/v1/users/${encodeURIComponent(targetUser)}`],
    ['targetAliases', 'admin.googleapis.com', `/admin/directory/v1/users/${encodeURIComponent(targetUser)}/aliases`],
    ['aliasAsUser', 'admin.googleapis.com', `/admin/directory/v1/users/${encodeURIComponent(aliasEmail)}`],
    ['aliasAsGroup', 'admin.googleapis.com', `/admin/directory/v1/groups/${encodeURIComponent(aliasEmail)}`],
  ];

  const report = {};
  for (const [key, hostname, path] of adminPaths) {
    const res = await getJson(adminToken, hostname, path);
    report[key] = {
      status: res.status,
      primaryEmail: res.body.primaryEmail,
      email: res.body.email,
      aliases: res.body.aliases,
      nonEditableAliases: res.body.nonEditableAliases,
      sendAs: (res.body.sendAs || []).map((item) => ({
        sendAsEmail: item.sendAsEmail,
        displayName: item.displayName,
        isDefault: item.isDefault,
        treatAsAlias: item.treatAsAlias,
        verificationStatus: item.verificationStatus,
      })),
      error: summarizeError(res),
    };
  }

  const sendAsRes = await getJson(
    gmailToken,
    'gmail.googleapis.com',
    `/gmail/v1/users/${encodeURIComponent(gmailImpersonateUser)}/settings/sendAs`,
  );
  report.sendAs = {
    status: sendAsRes.status,
    user: gmailImpersonateUser,
    sendAs: (sendAsRes.body.sendAs || []).map((item) => ({
      sendAsEmail: item.sendAsEmail,
      displayName: item.displayName,
      isDefault: item.isDefault,
      treatAsAlias: item.treatAsAlias,
      verificationStatus: item.verificationStatus,
    })),
    error: summarizeError(sendAsRes),
  };

  return report;
}

async function ensureAlias(token) {
  const userRes = await getJson(
    token,
    'admin.googleapis.com',
    `/admin/directory/v1/users/${encodeURIComponent(targetUser)}`,
  );

  const emails = (userRes.body.emails || []).map((item) => (item.address || '').toLowerCase());
  const nonEditableAliases = (userRes.body.nonEditableAliases || []).map((item) => item.toLowerCase());
  if (emails.includes(aliasEmail.toLowerCase()) || nonEditableAliases.includes(aliasEmail.toLowerCase())) {
    return { changed: false, reason: 'alias_exists_on_target_user' };
  }

  const aliasesRes = await getJson(
    token,
    'admin.googleapis.com',
    `/admin/directory/v1/users/${encodeURIComponent(targetUser)}/aliases`,
  );

  const aliases = aliasesRes.body.aliases || [];
  if (aliases.some((item) => (item.alias || '').toLowerCase() === aliasEmail.toLowerCase())) {
    return { changed: false, reason: 'alias_exists' };
  }

  const res = await api(
    token,
    'POST',
    'admin.googleapis.com',
    `/admin/directory/v1/users/${encodeURIComponent(targetUser)}/aliases`,
    { alias: aliasEmail },
  );

  if (res.status >= 400 && res.status !== 409) {
    return { changed: false, status: res.status, reason: 'alias_create_failed', error: summarizeError(res) };
  }

  return { changed: res.status < 300, status: res.status, reason: res.status === 409 ? 'alias_conflict' : 'alias_created' };
}

async function ensureSendAs(token) {
  const sendAsRes = await getJson(
    token,
    'gmail.googleapis.com',
    `/gmail/v1/users/${encodeURIComponent(gmailImpersonateUser)}/settings/sendAs`,
  );

  const sendAs = sendAsRes.body.sendAs || [];
  if (sendAs.some((item) => (item.sendAsEmail || '').toLowerCase() === aliasEmail.toLowerCase())) {
    return { changed: false, reason: 'send_as_exists' };
  }

  const res = await api(
    token,
    'POST',
    'gmail.googleapis.com',
    `/gmail/v1/users/${encodeURIComponent(gmailImpersonateUser)}/settings/sendAs`,
    {
      sendAsEmail: aliasEmail,
      displayName,
      replyToAddress: aliasEmail,
      treatAsAlias: true,
    },
  );

  if (res.status >= 400 && res.status !== 409) {
    throw new Error(`No se pudo crear sendAs: ${JSON.stringify(summarizeError(res))}`);
  }

  return { changed: res.status < 300, status: res.status, reason: res.status === 409 ? 'send_as_conflict' : 'send_as_created' };
}

async function ensureGroup(token) {
  const groupEmail = process.env.WORKSPACE_GROUP_EMAIL || 'publicidad@licitago.es';
  const memberEmail = process.env.WORKSPACE_GROUP_MEMBER || targetUser;

  let groupRes = await getJson(
    token,
    'admin.googleapis.com',
    `/admin/directory/v1/groups/${encodeURIComponent(groupEmail)}`,
  );

  let groupChanged = false;
  if (groupRes.status === 404) {
    groupRes = await api(
      token,
      'POST',
      'admin.googleapis.com',
      '/admin/directory/v1/groups',
      {
        email: groupEmail,
        name: 'Publicidad Astro Cluster',
        description: 'Contacto comercial del astro-cluster',
      },
    );
    if (groupRes.status >= 400) {
      throw new Error(`No se pudo crear grupo ${groupEmail}: ${JSON.stringify(summarizeError(groupRes))}`);
    }
    groupChanged = true;
  } else if (groupRes.status >= 400) {
    throw new Error(`No se pudo consultar grupo ${groupEmail}: ${JSON.stringify(summarizeError(groupRes))}`);
  }

  const memberRes = await api(
    token,
    'POST',
    'admin.googleapis.com',
    `/admin/directory/v1/groups/${encodeURIComponent(groupEmail)}/members`,
    { email: memberEmail, role: 'MEMBER' },
  );

  const memberExists = memberRes.status === 409;
  if (memberRes.status >= 400 && !memberExists) {
    throw new Error(`No se pudo anadir miembro ${memberEmail}: ${JSON.stringify(summarizeError(memberRes))}`);
  }

  return {
    group: {
      changed: groupChanged,
      email: groupRes.body.email,
      aliases: groupRes.body.aliases || [],
      nonEditableAliases: groupRes.body.nonEditableAliases || [],
    },
    member: {
      changed: !memberExists,
      email: memberEmail,
      reason: memberExists ? 'member_exists' : 'member_added',
    },
  };
}

async function groupSettings(token) {
  const groupEmail = process.env.WORKSPACE_GROUP_EMAIL || 'publicidad@licitago.es';
  return api(
    token,
    'GET',
    'groupssettings.googleapis.com',
    `/groups/v1/groups/${encodeURIComponent(groupEmail)}`,
  );
}

async function ensureGroupSettings(token) {
  const groupEmail = process.env.WORKSPACE_GROUP_EMAIL || 'publicidad@licitago.es';
  const before = await groupSettings(token);

  if (before.status >= 400) {
    throw new Error(`No se pudo consultar configuracion del grupo ${groupEmail}: ${JSON.stringify(summarizeError(before))}`);
  }

  const desired = {
    whoCanPostMessage: 'ANYONE_CAN_POST',
    messageModerationLevel: 'MODERATE_NONE',
    spamModerationLevel: 'ALLOW',
  };

  const changed = Object.entries(desired).some(([key, value]) => before.body[key] !== value);
  if (!changed) {
    return {
      changed: false,
      email: groupEmail,
      before: desired,
      after: desired,
      reason: 'group_settings_already_ready',
    };
  }

  const after = await api(
    token,
    'PATCH',
    'groupssettings.googleapis.com',
    `/groups/v1/groups/${encodeURIComponent(groupEmail)}`,
    desired,
  );

  if (after.status >= 400) {
    throw new Error(`No se pudo actualizar configuracion del grupo ${groupEmail}: ${JSON.stringify(summarizeError(after))}`);
  }

  return {
    changed: true,
    email: groupEmail,
    before: {
      whoCanPostMessage: before.body.whoCanPostMessage,
      messageModerationLevel: before.body.messageModerationLevel,
      spamModerationLevel: before.body.spamModerationLevel,
    },
    after: {
      whoCanPostMessage: after.body.whoCanPostMessage,
      messageModerationLevel: after.body.messageModerationLevel,
      spamModerationLevel: after.body.spamModerationLevel,
    },
  };
}

async function deleteUser(token, userEmail) {
  const res = await api(
    token,
    'DELETE',
    'admin.googleapis.com',
    `/admin/directory/v1/users/${encodeURIComponent(userEmail)}`,
  );

  if (res.status >= 400 && res.status !== 404) {
    throw new Error(`No se pudo eliminar usuario ${userEmail}: ${JSON.stringify(summarizeError(res))}`);
  }

  return { changed: res.status === 204, status: res.status, reason: res.status === 404 ? 'user_not_found' : 'user_deleted' };
}

async function main() {
  if (action === 'inspect') {
    const adminToken = await accessToken(adminScopes, adminUser);
    const gmailToken = await accessToken(gmailScopes, gmailImpersonateUser);
    console.log(JSON.stringify(await inspect(adminToken, gmailToken), null, 2));
    return;
  }

  if (action === 'ensure') {
    const adminToken = await accessToken(adminScopes, adminUser);
    const gmailToken = await accessToken(gmailScopes, gmailImpersonateUser);
    const alias = await ensureAlias(adminToken);
    const sendAs = await ensureSendAs(gmailToken);
    const after = await inspect(adminToken, gmailToken);
    console.log(JSON.stringify({ alias, sendAs, after }, null, 2));
    return;
  }

  if (action === 'ensure-group') {
    const adminToken = await accessToken(adminScopes, adminUser);
    const group = await ensureGroup(adminToken);
    console.log(JSON.stringify({ group }, null, 2));
    return;
  }

  if (action === 'inspect-group-settings') {
    const groupSettingsToken = await accessToken(groupSettingsScopes, adminUser);
    const settings = await groupSettings(groupSettingsToken);
    console.log(JSON.stringify({ status: settings.status, settings: settings.body, error: summarizeError(settings) }, null, 2));
    return;
  }

  if (action === 'ensure-group-settings') {
    const groupSettingsToken = await accessToken(groupSettingsScopes, adminUser);
    const settings = await ensureGroupSettings(groupSettingsToken);
    console.log(JSON.stringify({ settings }, null, 2));
    return;
  }

  if (action === 'delete-target-user') {
    const adminToken = await accessToken(adminScopes, adminUser);
    const deleted = await deleteUser(adminToken, targetUser);
    console.log(JSON.stringify({ deleted }, null, 2));
    return;
  }

  throw new Error(`Accion no soportada: ${action}. Usa inspect, ensure, ensure-group, inspect-group-settings, ensure-group-settings o delete-target-user.`);
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
