#!/usr/bin/env node
'use strict';
/**
 * Growth milestone checker for carta-astral-gratis.es
 * Reads GA4 metrics (via env vars from weekly report) and checks against
 * GROWTH_MILESTONES.json to determine current stage and next actions.
 *
 * Input (env vars): SESSIONS, USERS, VIEWS, DURATION, BOUNCE, ORGANIC_SESSIONS
 * Output: markdown report section for milestone progress
 */
const fs = require('fs');
const path = require('path');

const MILESTONES_PATH = path.join(process.cwd(), 'docs', 'GROWTH_MILESTONES.json');

/** Safely parse a numeric env var, returning 0 for NaN/undefined */
function envNum(name) {
  const v = Number(process.env[name]);
  return Number.isFinite(v) ? v : 0;
}

/** Build a visual progress bar of fixed length */
function progressBar(pct, len = 20) {
  const clamped = Math.max(0, Math.min(100, pct));
  const filled = Math.round(clamped / 100 * len);
  return '█'.repeat(filled) + '░'.repeat(len - filled);
}

/** Format a percentage from a 0-1 ratio */
function fmtPct(ratio) {
  return `${(ratio * 100).toFixed(1)}%`;
}

/** Evaluate a single KPI against its target */
function evalKpi(label, actual, target, comparator) {
  const ok = comparator === 'gte' ? actual >= target : actual <= target;
  const symbol = comparator === 'gte' ? '≥' : '≤';
  const fmtActual = typeof actual === 'number' && actual < 1 && actual >= 0
    ? fmtPct(actual) : String(actual);
  const fmtTarget = typeof target === 'number' && target < 1 && target >= 0
    ? fmtPct(target) : String(target);
  return `| ${label} | ${fmtActual} | ${symbol}${fmtTarget} | ${ok ? '✅' : '⚠️'} |`;
}

function main() {
  const sessions = envNum('SESSIONS');
  const users = envNum('USERS');
  const views = envNum('VIEWS');
  const bounce = envNum('BOUNCE');
  const duration = envNum('DURATION');
  const organicSessions = envNum('ORGANIC_SESSIONS');
  const chartCalc = envNum('CHART_CALCULATED');
  const interpGen = envNum('INTERPRETATION_GENERATED');

  let milestones;
  try {
    milestones = JSON.parse(fs.readFileSync(MILESTONES_PATH, 'utf8'));
  } catch (e) {
    console.error(`⚠️ Could not read ${MILESTONES_PATH}: ${e.message}`);
    process.exit(0);
  }

  const ms = milestones.milestones;
  if (!Array.isArray(ms) || ms.length === 0) {
    console.error('⚠️ No milestones defined in GROWTH_MILESTONES.json');
    process.exit(0);
  }

  const benchmarks = milestones.revenue_benchmarks_spain_esoteric || {};

  // Determine current milestone (highest achieved)
  let currentIdx = 0;
  for (let i = ms.length - 1; i >= 0; i--) {
    if (sessions >= ms[i].target_weekly_sessions) {
      currentIdx = i;
      break;
    }
  }
  const current = ms[currentIdx];
  const nextIdx = Math.min(currentIdx + 1, ms.length - 1);
  const next = ms[nextIdx];
  const progress = next.target_weekly_sessions > 0
    ? Math.min((sessions / next.target_weekly_sessions * 100), 100)
    : 100;

  // Revenue estimation based on current stage
  const monthlyPageViews = views * 4.3;
  const cpmTable = current.monetization === 'adsense-only'
    ? benchmarks.adsense_cpm_eur : benchmarks.moneytizer_cpm_eur;
  const cpm = cpmTable ? cpmTable.mid : 1;
  const estRevenue = ((monthlyPageViews / 1000) * cpm).toFixed(2);

  // Organic share
  const organicShare = sessions > 0 ? (organicSessions / sessions) : 0;

  // KPI evaluation
  const kpis = current.kpis || {};
  const kpiResults = [];
  if (kpis.organic_share_min !== undefined) {
    kpiResults.push(evalKpi('Organic share', organicShare, kpis.organic_share_min, 'gte'));
  }
  if (kpis.bounce_rate_max !== undefined) {
    kpiResults.push(evalKpi('Bounce rate', bounce, kpis.bounce_rate_max, 'lte'));
  }
  if (kpis.avg_duration_min_s !== undefined) {
    kpiResults.push(evalKpi('Avg duration', `${duration.toFixed(0)}s`, `${kpis.avg_duration_min_s}s`, 'gte'));
  }
  if (kpis.chart_calculated_min !== undefined) {
    kpiResults.push(evalKpi('Charts calc.', chartCalc, kpis.chart_calculated_min, 'gte'));
  }
  if (kpis.interpretation_generated_min !== undefined) {
    kpiResults.push(evalKpi('Interp. gen.', interpGen, kpis.interpretation_generated_min, 'gte'));
  }

  // Output markdown
  const lines = [
    `### 🚀 Growth Milestone Progress`,
    '',
    `| | Status |`,
    `|---|---|`,
    `| Current stage | **${current.id}: ${current.name}** |`,
    `| Next milestone | **${next.id}: ${next.name}** (${next.target_weekly_sessions} sessions/week) |`,
    `| Progress | \`${progressBar(progress)}\` ${progress.toFixed(1)}% |`,
    `| Weekly sessions | **${sessions}** |`,
    `| Monetization | ${current.monetization} |`,
    `| Est. monthly rev. | ~€${estRevenue} (${cpm}€ CPM) |`,
    '',
  ];

  if (kpiResults.length > 0) {
    lines.push('#### KPI Health');
    lines.push('| KPI | Current | Target | Status |');
    lines.push('|-----|---------|--------|--------|');
    lines.push(...kpiResults);
    lines.push('');
  }

  // Next actions
  if (currentIdx < ms.length - 1 && Array.isArray(next.actions)) {
    lines.push(`#### 📋 Next Actions (${next.id}: ${next.name})`);
    for (const a of next.actions) {
      lines.push(`- [ ] ${a}`);
    }
    lines.push('');
  }

  // Alert if milestone just reached (within 20% above threshold)
  if (currentIdx > 0 && sessions >= current.target_weekly_sessions &&
      sessions < current.target_weekly_sessions * 1.2) {
    lines.push(`> 🎉 **¡Milestone ${current.id} alcanzado!** Has superado ${current.target_weekly_sessions} sessions/week. Review the actions for this stage.`);
    lines.push('');
  }

  console.log(lines.join('\n'));

  // Update milestone statuses in JSON
  let needsUpdate = false;
  for (const m of ms) {
    const newStatus = sessions >= m.target_weekly_sessions ? 'achieved' :
      m === current ? 'in-progress' : 'pending';
    if (m.status !== newStatus) {
      m.status = newStatus;
      needsUpdate = true;
    }
  }
  if (needsUpdate) {
    milestones.updated = new Date().toISOString().slice(0, 10);
    fs.writeFileSync(MILESTONES_PATH, JSON.stringify(milestones, null, 2) + '\n', 'utf8');
  }
}

main();
