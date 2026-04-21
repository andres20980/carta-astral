#!/usr/bin/env node
'use strict';

const fs = require('fs');
const https = require('https');
const crypto = require('crypto');

const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
const user = process.env.WORKSPACE_GMAIL_IMPERSONATE || 'info@licitago.es';
const action = process.argv[2] || 'list';
const query = process.env.GMAIL_QUERY || 'newer_than:1d';
const from = process.env.ASTRO_MAIL_FROM || 'publicidad@carta-astral-gratis.es';
const to = process.env.ASTRO_MAIL_TO || 'poorku@gmail.com';
const subject = process.env.ASTRO_MAIL_SUBJECT || `Prueba salida publicidad ${new Date().toISOString().slice(0, 10)}`;
const mailBody = process.env.ASTRO_MAIL_BODY || `Prueba programatica de envio desde ${from} via Gmail API.`;

const scopes = [
  'https://www.googleapis.com/auth/gmail.readonly',
  'https://www.googleapis.com/auth/gmail.send',
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

async function accessToken() {
  if (!credentialsPath) throw new Error('Falta GOOGLE_APPLICATION_CREDENTIALS');
  const credentials = JSON.parse(fs.readFileSync(credentialsPath, 'utf8'));
  const now = Math.floor(Date.now() / 1000);
  const encodedHeader = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const encodedClaim = b64url(JSON.stringify({
    iss: credentials.client_email,
    scope: scopes.join(' '),
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    sub: user,
  }));
  const unsigned = `${encodedHeader}.${encodedClaim}`;
  const signer = crypto.createSign('RSA-SHA256');
  signer.update(unsigned);
  signer.end();

  const body = new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion: `${unsigned}.${b64url(signer.sign(credentials.private_key))}`,
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
    if (res.body?.error === 'unauthorized_client') {
      throw new Error([
        'La service account no tiene autorizados los scopes Gmail necesarios para pruebas.',
        'Anade estos scopes en Google Admin > Seguridad > Control de API > Delegacion de todo el dominio:',
        scopes.join(','),
      ].join('\n'));
    }
    throw new Error(`No se pudo obtener token Gmail: ${JSON.stringify(res.body)}`);
  }
  return res.body.access_token;
}

async function gmail(token, method, path, payload) {
  const body = payload ? JSON.stringify(payload) : undefined;
  const res = await request({
    method,
    hostname: 'gmail.googleapis.com',
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

  if (res.status >= 400) {
    throw new Error(`Gmail ${method} ${path}: ${JSON.stringify(res.body)}`);
  }
  return res.body;
}

function header(headers, name) {
  return (headers || []).find((item) => (item.name || '').toLowerCase() === name.toLowerCase())?.value || '';
}

function encodeHeader(value) {
  return /^[\x00-\x7F]*$/.test(value)
    ? value
    : `=?UTF-8?B?${Buffer.from(value, 'utf8').toString('base64')}?=`;
}

async function list(token) {
  const listRes = await gmail(
    token,
    'GET',
    `/gmail/v1/users/${encodeURIComponent(user)}/messages?q=${encodeURIComponent(query)}&maxResults=10`,
  );
  const rows = [];

  for (const message of listRes.messages || []) {
    const detail = await gmail(
      token,
      'GET',
      `/gmail/v1/users/${encodeURIComponent(user)}/messages/${message.id}?format=metadata&metadataHeaders=From&metadataHeaders=To&metadataHeaders=Subject&metadataHeaders=Date`,
    );
    const headers = detail.payload?.headers || [];
    rows.push({
      id: detail.id,
      threadId: detail.threadId,
      labelIds: detail.labelIds || [],
      internalDate: detail.internalDate ? new Date(Number(detail.internalDate)).toISOString() : '',
      from: header(headers, 'From'),
      to: header(headers, 'To'),
      subject: header(headers, 'Subject'),
      date: header(headers, 'Date'),
      snippet: (detail.snippet || '').replace(/\s+/g, ' ').trim(),
    });
  }

  console.log(JSON.stringify({ user, query, total: rows.length, rows }, null, 2));
}

async function send(token) {
  const raw = [
    `From: Astro Cluster <${from}>`,
    `To: ${to}`,
    `Reply-To: ${from}`,
    `Subject: ${encodeHeader(subject)}`,
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=UTF-8',
    '',
    mailBody,
  ].join('\r\n');

  const res = await gmail(
    token,
    'POST',
    `/gmail/v1/users/${encodeURIComponent(user)}/messages/send`,
    { raw: b64url(raw) },
  );
  console.log(JSON.stringify({ user, from, to, subject, messageId: res.id, threadId: res.threadId }, null, 2));
}

async function main() {
  const token = await accessToken();
  if (action === 'list') return list(token);
  if (action === 'send') return send(token);
  throw new Error(`Accion no soportada: ${action}. Usa list o send.`);
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
