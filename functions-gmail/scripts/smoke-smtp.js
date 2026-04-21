#!/usr/bin/env node
const crypto = require('crypto');
const tls = require('tls');

const user = process.env.GMAIL_USER;
const pass = process.env.GMAIL_PASS;
const from = process.env.ASTRO_MAIL_FROM || 'publicidad@carta-astral-gratis.es';
const to = process.env.ASTRO_MAIL_TO || from;
const subject = process.env.ASTRO_MAIL_SUBJECT || `Astro Cluster SMTP smoke ${new Date().toISOString()}`;
const textBody = process.env.ASTRO_MAIL_BODY || 'Prueba programatica de envio desde publicidad@carta-astral-gratis.es.';
const htmlBody = textBody
  .replace(/&/g, '&amp;')
  .replace(/</g, '&lt;')
  .replace(/>/g, '&gt;')
  .replace(/\n/g, '<br>');

if (!user || !pass) {
  console.error('Missing GMAIL_USER or GMAIL_PASS');
  process.exit(2);
}

const boundary = `astro-${crypto.randomBytes(8).toString('hex')}`;
const body = [
  `From: "Astro Cluster" <${from}>`,
  `To: ${to}`,
  `Subject: ${subject}`,
  'MIME-Version: 1.0',
  `Content-Type: multipart/alternative; boundary="${boundary}"`,
  '',
  `--${boundary}`,
  'Content-Type: text/plain; charset=UTF-8',
  '',
  textBody,
  '',
  `--${boundary}`,
  'Content-Type: text/html; charset=UTF-8',
  '',
  `<p>${htmlBody}</p>`,
  '',
  `--${boundary}--`,
  '',
].join('\r\n');

function readLine(socket) {
  return new Promise((resolve, reject) => {
    let data = '';
    const onError = (error) => {
      socket.off('data', onData);
      reject(error);
    };
    const onData = (chunk) => {
      data += chunk.toString('utf8');
      if (/\r?\n$/.test(data)) {
        socket.off('data', onData);
        socket.off('error', onError);
        resolve(data);
      }
    };
    socket.on('data', onData);
    socket.once('error', onError);
  });
}

async function expect(socket, command, acceptedCodes) {
  if (command) socket.write(`${command}\r\n`);
  let response = await readLine(socket);
  while (/^\d{3}-/.test(response.split(/\r?\n/).filter(Boolean).at(-1) || response)) {
    response += await readLine(socket);
  }
  const code = Number(response.slice(0, 3));
  if (!acceptedCodes.includes(code)) {
    throw new Error(`${command || 'connect'} failed: ${response.trim()}`);
  }
  return response.trim();
}

async function main() {
  const socket = tls.connect(465, 'smtp.gmail.com', { servername: 'smtp.gmail.com' });
  await new Promise((resolve, reject) => {
    socket.once('secureConnect', resolve);
    socket.once('error', reject);
  });

  await expect(socket, null, [220]);
  await expect(socket, 'EHLO carta-astral-gratis.es', [250]);
  await expect(socket, 'AUTH LOGIN', [334]);
  await expect(socket, Buffer.from(user).toString('base64'), [334]);
  await expect(socket, Buffer.from(pass).toString('base64'), [235]);
  await expect(socket, `MAIL FROM:<${from}>`, [250]);
  await expect(socket, `RCPT TO:<${to}>`, [250, 251]);
  await expect(socket, 'DATA', [354]);
  await expect(socket, `${body}\r\n.`, [250]);
  await expect(socket, 'QUIT', [221]);

  console.log(JSON.stringify({ success: true, from, to, subject }, null, 2));
}

main().catch((error) => {
  console.error(JSON.stringify({ success: false, error: error.message }, null, 2));
  process.exit(1);
});
