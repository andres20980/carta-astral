#!/usr/bin/env node
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

function main() {
  const sessions = Number(process.env.SESSIONS || 0);
  const users = Number(process.env.USERS || 0);
  const bounce = Number(process.env.BOUNCE || 0);
  const duration = Number(process.env.DURATION || 0);
  const organicSessions = Number(process.env.ORGANIC_SESSIONS || 0);
  const chartCalc = Number(process.env.CHART_CALCULATED || 0);
  const interpGen = Number(process.env.INTERPRETATION_GENERATED || 0);

  let milestones;
  try {
    milestones = JSON.parse(fs.readFileSync(MILESTONES_PATH, 'utf8'));
  } catch (e) {
    console.log('> ⚠️ Could not read GROWTH_MILESTONES.json');
    process.exit(0);
  }

  const ms = milestones.milestones;
  const benchmarks = milestones.revenue_benchmarks_spain_esoteric;

  // Determine current milestone
  let currentIdx = 0;
  for (let i = ms.length - 1; i >= 0; i--) {
    if (sessions >= ms[i].target_weekly_sessions) {
      currentIdx = i;
      break;
    }
  }
  const current = ms[currentIdx];
  const next = ms[Math.min(currentIdx + 1, ms.length - 1)];
  const progress = next.target_weekly_sessions > 0
    ? Math.min((sessions / next.target_weekly_sessions * 100), 100).toFixed(1)
    : '100';

  // Revenue estimation based on current stage
  const monthlyPageViews = Number(process.env.VIEWS || 0) * 4.3;
  const cpm = current.monetization === 'adsense-only'
    ? benchmarks.adsense_cpm_eur.mid
    : benchmarks.moneytizer_cpm_eur.mid;
  const estRevenue = ((monthlyPageViews / 1000) * cpm).toFixed(2);

  // Organic share
  const organicShare = sessions > 0 ? (organicSessions / sessions) : 0;

  // KPI check
  const kpis = current.kpis || {};
  const kpiResults = [];
  if (kpis.organic_share_min !== undefined) {
    const ok = organicShare >= kpis.organic_share_min;
    kpiResults.push(`| Organic share | ${(organicShare * 100).toFixed(1)}% | ≥${(kpis.organic_share_min * 100)}% | ${ok ? '✅' : '⚠️'} |`);
  }
  if (kpis.bounce_rate_max !== undefined) {
    const ok = bounce <= kpis.bounce_rate_max;
    kpiResults.push(`| Bounce rate | ${(bounce * 100).toFixed(1)}% | ≤${(kpis.bounce_rate_max * 100)}% | ${ok ? '✅' : '⚠️'} |`);
  }
  if (kpis.avg_duration_min_s !== undefined) {
    const ok = duration >= kpis.avg_duration_min_s;
    kpiResults.push(`| Avg duration | ${duration.toFixed(0)}s | ≥${kpis.avg_duration_min_s}s | ${ok ? '✅' : '⚠️'} |`);
  }
  if (kpis.chart_calculated_min !== undefined) {
    const ok = chartCalc >= kpis.chart_calculated_min;
    kpiResults.push(`| Charts calc. | ${chartCalc} | ≥${kpis.chart_calculated_min} | ${ok ? '✅' : '⚠️'} |`);
  }
  if (kpis.interpretation_generated_min !== undefined) {
    const ok = interpGen >= kpis.interpretation_generated_min;
    kpiResults.push(`| Interp. gen. | ${interpGen} | ≥${kpis.interpretation_generated_min} | ${ok ? '✅' : '⚠️'} |`);
  }

  // Build progress bar
  const barLen = 20;
  const filled = Math.round(parseFloat(progress) / 100 * barLen);
  const bar = '█'.repeat(filled) + '░'.repeat(barLen - filled);

  // Output markdown
  const lines = [
    `### 🚀 Growth Milestone Progress`,
    '',
    `| | Status |`,
    `|---|---|`,
    `| Current stage | **${current.id}: ${current.name}** |`,
    `| Next milestone | **${next.id}: ${next.name}** (${next.target_weekly_sessions} sessions/week) |`,
    `| Progress | \`${bar}\` ${progress}% |`,
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
  if (currentIdx < ms.length - 1) {
    lines.push(`#### 📋 Next Actions (${next.id}: ${next.name})`);
    for (const a of next.actions) {
      lines.push(`- [ ] ${a}`);
    }
    lines.push('');
  }

  // Alert if milestone just reached
  if (sessions >= current.target_weekly_sessions && currentIdx > 0) {
    const prev = ms[currentIdx - 1];
    if (sessions >= current.target_weekly_sessions && sessions < current.target_weekly_sessions * 1.2) {
      lines.push(`> 🎉 **¡Milestone ${current.id} alcanzado!** Has superado ${current.target_weekly_sessions} sessions/week. Review the actions for this stage.`);
      lines.push('');
    }
  }

  console.log(lines.join('\n'));

  // Also update milestone statuses in the JSON file
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
    fs.writeFileSync(MILESTONES_PATH, JSON.stringify(milestones, null, 2), 'utf8');
  }
}

main();
