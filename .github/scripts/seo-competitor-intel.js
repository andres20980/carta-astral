#!/usr/bin/env node

/**
 * seo-competitor-intel.js
 *
 * Crawlea páginas de competidores para "carta astral gratis" y keywords afines.
 * Extrae title, description, H1s, H2s, conteo de palabras, FAQ/HowTo schema y estructura.
 * Guarda resultados en docs/SEO_COMPETITOR_INTEL.json para que el learning-loop los use.
 *
 * Sin dependencias externas: usa solo módulos built-in de Node.js.
 */

const https = require('https');
const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = process.cwd();
const OUTPUT_PATH = path.join(ROOT, 'docs', 'SEO_COMPETITOR_INTEL.json');
const RULES_PATH = path.join(ROOT, '.github', 'config', 'seo-autopatch-rules.json');

const DEFAULT_COMPETITOR_URLS = [
  'https://www.losarcanos.com/carta-astral.php',
  'https://carta-natal.es/carta.php',
  'https://www.astro-seek.com/es/carta-natal-horoscopo-online',
  'https://www.tucartaastral.com/',
  'https://www.horoscopo.com/carta-astral',
];

const KEYWORDS_CONTEXT = [
  'carta astral',
  'carta natal',
  'mapa astral',
  'ascendente',
  'casas astrales',
  'hora de nacimiento',
  'gratis',
  'calcular',
  'signos',
  'planetas',
];

function loadCompetitorUrls() {
  try {
    const rules = JSON.parse(fs.readFileSync(RULES_PATH, 'utf8'));
    if (Array.isArray(rules.competitors) && rules.competitors.length > 0) {
      return rules.competitors;
    }
  } catch (_) {}
  return DEFAULT_COMPETITOR_URLS;
}

function fetchUrl(rawUrl, timeoutMs = 10000) {
  return new Promise((resolve) => {
    const url = new URL(rawUrl);
    const requester = url.protocol === 'https:' ? https : http;

    const options = {
      hostname: url.hostname,
      path: url.pathname + url.search,
      method: 'GET',
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; CartaAstralSEOBot/1.0)',
        Accept: 'text/html,application/xhtml+xml',
        'Accept-Language': 'es-ES,es;q=0.9',
      },
      timeout: timeoutMs,
    };

    let redirects = 0;

    function doRequest(opts, currentUrl) {
      const proto = new URL(currentUrl).protocol === 'https:' ? https : http;
      const req = proto.request(opts, (res) => {
        if ([301, 302, 303, 307, 308].includes(res.statusCode) && res.headers.location && redirects < 4) {
          redirects++;
          try {
            const next = new URL(res.headers.location, currentUrl);
            doRequest(
              {...opts, hostname: next.hostname, path: next.pathname + next.search},
              next.href
            );
          } catch (_) {
            resolve({url: currentUrl, status: res.statusCode, html: '', error: 'redirect_error'});
          }
          return;
        }

        if (res.statusCode !== 200) {
          resolve({url: currentUrl, status: res.statusCode, html: '', error: `http_${res.statusCode}`});
          return;
        }

        const chunks = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => resolve({url: currentUrl, status: 200, html: Buffer.concat(chunks).toString('utf8'), error: null}));
        res.on('error', (err) => resolve({url: currentUrl, status: 0, html: '', error: err.message}));
      });

      req.on('timeout', () => { req.destroy(); resolve({url: currentUrl, status: 0, html: '', error: 'timeout'}); });
      req.on('error', (err) => resolve({url: currentUrl, status: 0, html: '', error: err.message}));
      req.end();
    }

    doRequest(options, rawUrl);
  });
}

function extractTag(html, regex) {
  const match = html.match(regex);
  return match ? match[1].trim() : null;
}

function extractAllMatches(html, regex) {
  const results = [];
  let match;
  const re = new RegExp(regex.source, 'gi');
  while ((match = re.exec(html)) !== null) {
    results.push(match[1].trim().replace(/<[^>]*>/g, '').trim());
  }
  return results.filter(Boolean);
}

function countWords(html) {
  const text = html
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return text ? text.split(' ').length : 0;
}

function detectStructuredDataTypes(html) {
  const types = [];
  const scriptMatches = html.matchAll(/<script[^>]*type="application\/ld\+json"[^>]*>([\s\S]*?)<\/script>/gi);
  for (const m of scriptMatches) {
    try {
      const obj = JSON.parse(m[1]);
      const typeVal = obj['@type'];
      if (typeVal) types.push(...(Array.isArray(typeVal) ? typeVal : [typeVal]));
    } catch (_) {}
  }
  return [...new Set(types)];
}

function countKeywordPresence(html, keywords) {
  const text = html.replace(/<[^>]+>/g, ' ').toLowerCase();
  const result = {};
  for (const kw of keywords) {
    const escaped = kw.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const matches = text.match(new RegExp(escaped, 'g'));
    result[kw] = matches ? matches.length : 0;
  }
  return result;
}

function analyzeHtml(url, html) {
  const title = extractTag(html, /<title[^>]*>([^<]+)<\/title>/i);
  const description = extractTag(html, /<meta\s+name="description"\s+content="([^"]+)"/i)
    || extractTag(html, /<meta\s+content="([^"]+)"\s+name="description"/i);
  const canonical = extractTag(html, /<link\s+rel="canonical"\s+href="([^"]+)"/i);
  const h1s = extractAllMatches(html, /<h1[^>]*>(.*?)<\/h1>/i);
  const h2s = extractAllMatches(html, /<h2[^>]*>(.*?)<\/h2>/i);
  const wordCount = countWords(html);
  const schemaTypes = detectStructuredDataTypes(html);
  const keywordFrequency = countKeywordPresence(html, KEYWORDS_CONTEXT);

  return {
    url,
    fetchedAt: new Date().toISOString(),
    title,
    description,
    canonical,
    h1: h1s[0] || null,
    h1Count: h1s.length,
    h2s: h2s.slice(0, 10),
    h2Count: h2s.length,
    wordCount,
    schemaTypes,
    hasFaqSchema: schemaTypes.includes('FAQPage'),
    hasHowToSchema: schemaTypes.includes('HowTo'),
    hasBreadcrumb: schemaTypes.includes('BreadcrumbList'),
    internalLinks: (html.match(/href="\/[^"]+"/g) || []).length,
    keywordFrequency,
  };
}

function buildSeoInsights(results) {
  const successful = results.filter((r) => r.status === 200 && r.analysis);
  if (successful.length === 0) return null;

  const avgWordCount = Math.round(
    successful.reduce((sum, r) => sum + r.analysis.wordCount, 0) / successful.length
  );
  const faqAdopters = successful.filter((r) => r.analysis.hasFaqSchema).length;
  const howToAdopters = successful.filter((r) => r.analysis.hasHowToSchema).length;
  const breadcrumbAdopters = successful.filter((r) => r.analysis.hasBreadcrumb).length;

  const keywordTotals = {};
  for (const kw of KEYWORDS_CONTEXT) {
    keywordTotals[kw] = successful.reduce((sum, r) => sum + (r.analysis.keywordFrequency[kw] || 0), 0);
  }
  const topKeywords = Object.entries(keywordTotals)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([kw, count]) => ({keyword: kw, totalMentions: count}));

  const allH2s = successful.flatMap((r) => r.analysis.h2s || []);
  const h2Freq = {};
  for (const h2 of allH2s) {
    const key = h2.toLowerCase().trim();
    h2Freq[key] = (h2Freq[key] || 0) + 1;
  }
  const topH2Patterns = Object.entries(h2Freq)
    .filter(([, count]) => count > 1)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 8)
    .map(([text, count]) => ({text, occurrences: count}));

  return {
    crawledCount: results.length,
    successCount: successful.length,
    avgWordCount,
    faqSchemaAdoption: `${faqAdopters}/${successful.length}`,
    howToSchemaAdoption: `${howToAdopters}/${successful.length}`,
    breadcrumbAdoption: `${breadcrumbAdopters}/${successful.length}`,
    topKeywords,
    commonH2Patterns: topH2Patterns,
    recommendation: avgWordCount > 800
      ? `Competidores tienen de media ${avgWordCount} palabras. Asegúrate de que tu landing supera ese umbral.`
      : `Media de competidores: ${avgWordCount} palabras. Tu landing ya es competitiva en longitud.`,
  };
}

async function main() {
  const urls = loadCompetitorUrls();
  console.log(`🔍 Crawleando ${urls.length} URLs de competidores...`);

  const results = [];
  for (const url of urls) {
    process.stdout.write(`  → ${url} ... `);
    try {
      const {url: finalUrl, status, html, error} = await fetchUrl(url);
      if (error || status !== 200) {
        process.stdout.write(`✗ (${error || status})\n`);
        results.push({url, finalUrl, status, error, analysis: null});
      } else {
        const analysis = analyzeHtml(finalUrl, html);
        process.stdout.write(`✓ (${analysis.wordCount}w, ${analysis.h2Count} H2s)\n`);
        results.push({url, finalUrl, status, error: null, analysis});
      }
    } catch (err) {
      process.stdout.write(`✗ (${err.message})\n`);
      results.push({url, finalUrl: url, status: 0, error: err.message, analysis: null});
    }
    await new Promise((resolve) => setTimeout(resolve, 1500));
  }

  const insights = buildSeoInsights(results);
  const outputId = crypto.randomBytes(4).toString('hex');

  const output = {
    generatedAt: new Date().toISOString(),
    runId: outputId,
    keywordsContext: KEYWORDS_CONTEXT,
    insights,
    results: results.map((r) => ({url: r.url, status: r.status, error: r.error, analysis: r.analysis})),
  };

  const dir = path.dirname(OUTPUT_PATH);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, {recursive: true});
  fs.writeFileSync(OUTPUT_PATH, JSON.stringify(output, null, 2), 'utf8');

  console.log(`\n✅ Resultados guardados en ${OUTPUT_PATH}`);
  if (insights) {
    console.log(`📊 Media palabras competidores: ${insights.avgWordCount}`);
    console.log(`📊 FAQ schema: ${insights.faqSchemaAdoption} | HowTo: ${insights.howToSchemaAdoption} | Breadcrumb: ${insights.breadcrumbAdoption}`);
    console.log(`📊 Keywords más repetidas: ${insights.topKeywords.map((k) => k.keyword).join(', ')}`);
  }
}

main().catch((err) => {
  console.error('Error en seo-competitor-intel:', err.message);
  process.exit(1);
});
