const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const nodemailer = require('nodemailer');

const gmailUser = defineSecret('GMAIL_USER');
const gmailPass = defineSecret('GMAIL_PASS');
const astroGmailApiKey = defineSecret('ASTRO_GMAIL_API_KEY');

const REGION = 'europe-west1';
const ASTRO_FROM = 'publicidad@carta-astral-gratis.es';
const ALLOWED_ORIGINS = [
  'https://carta-astral-gratis.es',
  'https://compatibilidad-signos.es',
  'https://horoscopo-de-hoy.es',
  'https://tarot-del-dia.es',
  'https://calcular-numerologia.es',
];

function isAllowedOrigin(origin) {
  return !origin || ALLOWED_ORIGINS.some((allowed) => origin.startsWith(allowed));
}

function buildTransporter() {
  return nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: gmailUser.value(),
      pass: gmailPass.value(),
    },
  });
}

exports.sendAstroClusterEmail = onRequest({
  region: REGION,
  cors: ALLOWED_ORIGINS,
  invoker: 'public',
  secrets: [gmailUser, gmailPass, astroGmailApiKey],
  timeoutSeconds: 30,
  memory: '256MiB',
  minInstances: 0,
  maxInstances: 5,
}, async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const origin = req.headers.origin || req.headers.referer || '';
  if (!isAllowedOrigin(origin)) {
    return res.status(403).json({ error: 'Origin not allowed' });
  }

  const providedKey = req.get('x-astro-mail-key') || '';
  if (!providedKey || providedKey !== astroGmailApiKey.value()) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const { to, subject, text, html, replyTo } = req.body || {};
  if (!to || !subject || (!text && !html)) {
    return res.status(400).json({ error: 'Missing to, subject and body' });
  }

  try {
    const info = await buildTransporter().sendMail({
      from: `"Astro Cluster" <${ASTRO_FROM}>`,
      replyTo: replyTo || ASTRO_FROM,
      to,
      subject,
      text,
      html,
    });

    return res.status(200).json({
      success: true,
      messageId: info.messageId,
      accepted: info.accepted,
      rejected: info.rejected,
      envelope: info.envelope,
    });
  } catch (error) {
    return res.status(502).json({
      error: error.message,
      code: error.code,
      responseCode: error.responseCode,
      command: error.command,
    });
  }
});
