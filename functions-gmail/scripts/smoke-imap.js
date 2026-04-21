#!/usr/bin/env node
'use strict';

const tls = require('tls');

const user = process.env.GMAIL_USER;
const pass = process.env.GMAIL_PASS;
const queryTo = process.env.ASTRO_MAIL_TO || 'publicidad@carta-astral-gratis.es';
const subject = process.env.ASTRO_MAIL_SUBJECT || '';
const maxAttempts = Number(process.env.IMAP_POLL_ATTEMPTS || '6');
const pollDelayMs = Number(process.env.IMAP_POLL_DELAY_MS || '5000');

if (!user || !pass) {
  console.error('Missing GMAIL_USER or GMAIL_PASS');
  process.exit(2);
}

if (!subject) {
  console.error('Missing ASTRO_MAIL_SUBJECT');
  process.exit(2);
}

function quote(value) {
  return `"${String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

class ImapClient {
  constructor() {
    this.tag = 0;
    this.buffer = '';
    this.waiters = [];
    this.socket = tls.connect(993, 'imap.gmail.com', { servername: 'imap.gmail.com' });
    this.socket.on('data', (chunk) => this.onData(chunk));
  }

  async connect() {
    await new Promise((resolve, reject) => {
      this.socket.once('secureConnect', resolve);
      this.socket.once('error', reject);
    });
    const greeting = await this.readUntil((lines) => lines.some((line) => line.startsWith('* OK')));
    if (!greeting.some((line) => line.startsWith('* OK'))) {
      throw new Error(`IMAP greeting failed: ${greeting.join(' | ')}`);
    }
  }

  onData(chunk) {
    this.buffer += chunk.toString('utf8');
    this.flush();
  }

  flush() {
    const lines = this.buffer.split(/\r?\n/);
    this.buffer = lines.pop() || '';
    while (lines.length) {
      const line = lines.shift();
      const waiter = this.waiters[0];
      if (!waiter) continue;
      waiter.lines.push(line);
      if (waiter.done(waiter.lines)) {
        this.waiters.shift();
        waiter.resolve(waiter.lines);
      }
    }
  }

  readUntil(done) {
    return new Promise((resolve, reject) => {
      const onError = (error) => {
        this.waiters = this.waiters.filter((item) => item.resolve !== resolve);
        reject(error);
      };
      this.socket.once('error', onError);
      this.waiters.push({
        lines: [],
        done: (lines) => {
          const complete = done(lines);
          if (complete) this.socket.off('error', onError);
          return complete;
        },
        resolve,
      });
      this.flush();
    });
  }

  async command(command) {
    const tag = `A${String(++this.tag).padStart(4, '0')}`;
    this.socket.write(`${tag} ${command}\r\n`);
    const lines = await this.readUntil((rows) => rows.some((line) => line.startsWith(`${tag} `)));
    const final = lines.find((line) => line.startsWith(`${tag} `)) || '';
    if (!final.includes(' OK ')) {
      throw new Error(`${command} failed: ${lines.join(' | ')}`);
    }
    return lines;
  }

  close() {
    this.socket.end();
  }
}

async function searchOnce() {
  const client = new ImapClient();
  await client.connect();
  try {
    await client.command(`LOGIN ${quote(user)} ${quote(pass)}`);
    await client.command('SELECT INBOX');
    const rawQuery = `to:${queryTo} subject:"${subject}"`;
    const lines = await client.command(`SEARCH X-GM-RAW ${quote(rawQuery)}`);
    const searchLine = lines.find((line) => line.startsWith('* SEARCH')) || '* SEARCH';
    const ids = searchLine.replace('* SEARCH', '').trim().split(/\s+/).filter(Boolean);
    await client.command('LOGOUT');
    return ids;
  } finally {
    client.close();
  }
}

async function main() {
  let ids = [];
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    ids = await searchOnce();
    if (ids.length) {
      console.log(JSON.stringify({ success: true, to: queryTo, subject, matches: ids.length, ids }, null, 2));
      return;
    }
    if (attempt < maxAttempts) await sleep(pollDelayMs);
  }
  console.log(JSON.stringify({ success: false, to: queryTo, subject, matches: 0 }, null, 2));
  process.exit(1);
}

main().catch((error) => {
  console.error(JSON.stringify({ success: false, error: error.message }, null, 2));
  process.exit(1);
});
