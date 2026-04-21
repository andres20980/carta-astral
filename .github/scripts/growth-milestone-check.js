#!/usr/bin/env node
'use strict';
/**
 * Cluster growth milestone checker.
 * Combines weekly performance metrics with repo-level capability signals so
 * GROWTH_MILESTONES.json can evolve automatically as the cluster matures.
 *
 * Input env vars:
 * - SESSIONS, USERS, VIEWS, DURATION, BOUNCE, ORGANIC_SESSIONS
 * - CHART_CALCULATED, INTERPRETATION_GENERATED
 * - GSC_VERIFIED_SITE_COUNT
 */
const fs = require('fs');
const path = require('path');

const ROOT = process.cwd();
const MILESTONES_PATH = path.join(ROOT, 'docs', 'GROWTH_MILESTONES.json');
const SITE_KEYS = [
  'carta-astral',
  'compatibilidad-signos',
  'tarot-del-dia',
  'calcular-numerologia',
  'horoscopo-de-hoy',
];

function repoPath(...parts) {
  return path.join(ROOT, ...parts);
}

function envNum(name) {
  const v = Number(process.env[name]);
  return Number.isFinite(v) ? v : 0;
}

function exists(relPath) {
  return fs.existsSync(repoPath(relPath));
}

function read(relPath) {
  try {
    return fs.readFileSync(repoPath(relPath), 'utf8');
  } catch {
    return '';
  }
}

function progressBar(pct, len = 20) {
  const clamped = Math.max(0, Math.min(100, pct));
  const filled = Math.round((clamped / 100) * len);
  return '█'.repeat(filled) + '░'.repeat(len - filled);
}

function fmtPct(ratio) {
  return `${(ratio * 100).toFixed(1)}%`;
}

function evalKpi(label, actual, target, comparator) {
  const ok = comparator === 'gte' ? actual >= target : actual <= target;
  const symbol = comparator === 'gte' ? '≥' : '≤';
  const fmtActual = typeof actual === 'number' && actual < 1 && actual >= 0
    ? fmtPct(actual) : String(actual);
  const fmtTarget = typeof target === 'number' && target < 1 && target >= 0
    ? fmtPct(target) : String(target);
  return `| ${label} | ${fmtActual} | ${symbol}${fmtTarget} | ${ok ? '✅' : '⚠️'} |`;
}

function walkHtmlFiles(dirPath) {
  let total = 0;
  if (!fs.existsSync(dirPath)) {
    return total;
  }
  for (const entry of fs.readdirSync(dirPath, { withFileTypes: true })) {
    const fullPath = path.join(dirPath, entry.name);
    if (entry.isDirectory()) {
      total += walkHtmlFiles(fullPath);
    } else if (entry.isFile() && entry.name.endsWith('.html')) {
      total += 1;
    }
  }
  return total;
}

function countOccurrences(text, needle) {
  if (!text || !needle) {
    return 0;
  }
  return text.split(needle).length - 1;
}

function countGa4OptOutCoverage(dirPath) {
  const totals = { tagged: 0, optOut: 0 };
  if (!fs.existsSync(dirPath)) {
    return totals;
  }
  for (const entry of fs.readdirSync(dirPath, { withFileTypes: true })) {
    const fullPath = path.join(dirPath, entry.name);
    if (entry.isDirectory()) {
      const nested = countGa4OptOutCoverage(fullPath);
      totals.tagged += nested.tagged;
      totals.optOut += nested.optOut;
    } else if (entry.isFile() && entry.name.endsWith('.html')) {
      const html = fs.readFileSync(fullPath, 'utf8');
      if (html.includes('googletagmanager.com/gtag/js')) {
        totals.tagged += 1;
        if (html.includes('astro_cluster_analytics_optout')) {
          totals.optOut += 1;
        }
      }
    }
  }
  return totals;
}

function repoSignals() {
  const shared = read('shared/config.sh');
  const deployWorkflow = read('.github/workflows/deploy-all-sites.yml');
  const smokeWorkflow = read('.github/workflows/seo-smoke-all.yml');
  const weeklyWorkflow = read('.github/workflows/weekly-google-report.yml');
  const seoAutoWorkflow = read('.github/workflows/seo-auto-pr.yml');
  const seoSiteSelector = read('.github/scripts/select_seo_site.py');
  const seoRulesRaw = read('.github/config/seo-autopatch-rules.json');
  const cartaIndex = read('sites/carta-astral/public/index.html');

  let seoRules = {};
  try {
    seoRules = JSON.parse(seoRulesRaw);
  } catch {
    seoRules = {};
  }

  const publicHtmlBySite = {};
  let totalHtmlPages = 0;
  let publicidadCoverage = 0;
  let clusterRecirculationCoverage = 0;
  let premiumSlotCoverage = 0;
  let adsTxtCoverage = 0;
  const ga4Coverage = { tagged: 0, optOut: 0 };

  for (const site of SITE_KEYS) {
    const publicDir = repoPath('sites', site, 'public');
    const scriptPath = repoPath('sites', site, 'scripts', 'gen-pages.sh');
    const scriptBody = read(path.join('sites', site, 'scripts', 'gen-pages.sh'));
    const publicIndex = read(path.join('sites', site, 'public', 'index.html'));
    const htmlCount = walkHtmlFiles(publicDir);
    publicHtmlBySite[site] = htmlCount;
    totalHtmlPages += htmlCount;
    const siteGa4Coverage = countGa4OptOutCoverage(publicDir);
    ga4Coverage.tagged += siteGa4Coverage.tagged;
    ga4Coverage.optOut += siteGa4Coverage.optOut;

    if (exists(path.join('sites', site, 'public', 'publicidad.html')) || scriptBody.includes('gen_publicidad_page')) {
      publicidadCoverage += 1;
    }
    if (exists(path.join('sites', site, 'public', 'ads.txt'))) {
      adsTxtCoverage += 1;
    }
    if (
      scriptBody.includes('cluster_recirculation_block') ||
      (site === 'carta-astral' && cartaIndex.includes('cluster-suite'))
    ) {
      clusterRecirculationCoverage += 1;
    }
    if (countOccurrences(scriptBody, 'ad_block "') >= 2 || countOccurrences(publicIndex, 'ad-ph ') >= 2) {
      premiumSlotCoverage += 1;
    }
  }

  const trackingDomains = [
    'carta-astral-gratis.es',
    'compatibilidad-signos.es',
    'tarot-del-dia.es',
    'calcular-numerologia.es',
    'horoscopo-de-hoy.es',
  ];
  const trackingDomainsCoverage = trackingDomains.filter((domain) => shared.includes(`"${domain}"`)).length;
  const gscSiteConfigCoverage = SITE_KEYS.filter((site) => shared.includes(`[${site}]="sc-domain:`)).length;
  const autoPatchSiteCount = Object.keys(seoRules.sites || {}).length + (seoRules.rulesByQuery ? 1 : 0);
  const selectorCoversAllSites = SITE_KEYS.every((site) => seoSiteSelector.includes(`"${site}"`));

  return {
    siteCount: SITE_KEYS.length,
    publicHtmlBySite,
    totalHtmlPages,
    ga4Unified: SITE_KEYS.every((site) => shared.includes(`[${site}]="$CLUSTER_GA4_ID"`)),
    trackingDomainsComplete: trackingDomainsCoverage === SITE_KEYS.length,
    sharedAdsensePub: /ADSENSE_PUB="ca-pub-\d+"/.test(shared),
    adsTxtCoverageComplete: adsTxtCoverage === SITE_KEYS.length,
    gscSitesConfigured: gscSiteConfigCoverage === SITE_KEYS.length,
    deploySelective: deployWorkflow.includes('detect-changes') && deployWorkflow.includes('shared/') && deployWorkflow.includes('SITES+='),
    seoSmokeCluster: smokeWorkflow.includes('/publicidad') && exists('.github/scripts/seo_smoke_html_checks.py'),
    seoAutopatchRotatory: seoAutoWorkflow.includes('select_seo_site.py') &&
      seoAutoWorkflow.includes('SEO_AUTO_PR_MAX_CHANGES') &&
      selectorCoversAllSites &&
      autoPatchSiteCount >= SITE_KEYS.length,
    gscClusterReporting: weeklyWorkflow.includes('GSC_SITES_JSON') && exists('.github/scripts/weekly_gsc_report.py'),
    gscSitemapSubmit: deployWorkflow.includes('Enviar sitemap a GSC') && deployWorkflow.includes('searchconsole.googleapis.com/webmasters/v3/sites'),
    clusterMediaKits: publicidadCoverage === SITE_KEYS.length,
    clusterRecirculation: clusterRecirculationCoverage === SITE_KEYS.length,
    premiumSlotsBySite: premiumSlotCoverage === SITE_KEYS.length,
    clusterSuiteEntrypoint: cartaIndex.includes('cluster-suite'),
    longTailCoverage: totalHtmlPages >= 180,
    ga4TaggedPages: ga4Coverage.tagged,
    ga4OptOutPages: ga4Coverage.optOut,
    internalTrafficOptOut: ga4Coverage.tagged > 0 &&
      ga4Coverage.optOut === ga4Coverage.tagged &&
      shared.includes('analytics_optout') &&
      shared.includes('ga-disable-'),
    eeatSchemasPresent: SITE_KEYS.filter((site) => {
      const body = read(path.join('sites', site, 'scripts', 'gen-pages.sh')) + read(path.join('sites', site, 'public', 'index.html'));
      return body.includes('"@type":"FAQPage"') && body.includes('"@type":"BreadcrumbList"');
    }).length === SITE_KEYS.length,
  };
}

function actionStatus(label, signals, gscVerifiedSiteCount) {
  const checks = [
    {
      re: /GA4 unificado/i,
      done: signals.ga4Unified && signals.trackingDomainsComplete,
      evidence: `GA4 cluster + linker cross-domain en ${signals.siteCount}/${signals.siteCount} sites`,
    },
    {
      re: /Ads\.txt y AdSense consistentes/i,
      done: signals.sharedAdsensePub && signals.adsTxtCoverageComplete,
      evidence: `Publisher compartido y ads.txt generado para ${signals.siteCount}/${signals.siteCount} sites`,
    },
    {
      re: /Smoke SEO y deploy selectivo activos/i,
      done: signals.seoSmokeCluster && signals.deploySelective,
      evidence: 'Smoke cluster + deploy selectivo detectados en workflows',
    },
    {
      re: /Autoparcheo SEO rotatorio/i,
      done: signals.seoAutopatchRotatory,
      evidence: 'Workflow diario con rotación de sitio y autoparche limitado',
    },
    {
      re: /Verificar las 5 propiedades de GSC por DNS/i,
      done: gscVerifiedSiteCount >= signals.siteCount,
      evidence: `Propiedades GSC verificadas: ${gscVerifiedSiteCount}/${signals.siteCount}`,
    },
    {
      re: /Extender reporting GSC por dominio/i,
      done: signals.gscClusterReporting,
      evidence: 'Informe semanal agrega GSC por dominio',
    },
    {
      re: /Ampliar landings long-tail/i,
      done: signals.longTailCoverage,
      evidence: `${signals.totalHtmlPages} páginas HTML públicas en el cluster`,
    },
    {
      re: /Refinar interlinking interno por intencion/i,
      done: signals.clusterRecirculation && signals.clusterSuiteEntrypoint,
      evidence: `Bloques de recirculacion presentes en ${signals.siteCount}/${signals.siteCount} sites`,
    },
    {
      re: /Vender banners directos desde \/publicidad/i,
      done: signals.clusterMediaKits,
      evidence: `/publicidad disponible en ${signals.siteCount}/${signals.siteCount} sites`,
    },
    {
      re: /Mantener AdSense como remanente/i,
      done: signals.sharedAdsensePub,
      evidence: 'Publisher de AdSense compartido a nivel cluster',
    },
    {
      re: /Definir slots reservados para venta directa por site/i,
      done: signals.premiumSlotsBySite,
      evidence: `Slots premium detectados en ${signals.siteCount}/${signals.siteCount} sites`,
    },
    {
      re: /Crear paginas comerciales y media kit cluster/i,
      done: signals.clusterMediaKits,
      evidence: 'Media kits individuales activos y consistentes',
    },
    {
      re: /Construir mas herramientas complementarias/i,
      done: signals.siteCount >= 5,
      evidence: `${signals.siteCount} herramientas activas en el cluster`,
    },
    {
      re: /Ampliar comparativas y contenidos evergreen con E-E-A-T/i,
      done: signals.longTailCoverage && signals.eeatSchemasPresent,
      evidence: `${signals.totalHtmlPages} páginas + FAQ/Breadcrumb presentes en todos los sitios`,
    },
    {
      re: /Abrir afiliacion y patrocinios recurrentes/i,
      done: false,
      evidence: 'Aun sin circuito recurrente de afiliacion confirmado en repo',
    },
    {
      re: /Optimizar RPM combinando banner directo y remanente/i,
      done: signals.clusterMediaKits && signals.sharedAdsensePub && signals.premiumSlotsBySite,
      evidence: 'Inventario directo + remanente disponible a nivel de producto',
    },
  ];

  for (const check of checks) {
    if (check.re.test(label)) {
      return { done: check.done, evidence: check.evidence };
    }
  }
  return { done: false, evidence: 'Sin heuristica automatica para esta accion' };
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
  const gscVerifiedSiteCount = envNum('GSC_VERIFIED_SITE_COUNT');

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

  const signals = repoSignals();
  const benchmarks = milestones.revenue_benchmarks_spain_esoteric || {};

  let currentIdx = 0;
  for (let i = ms.length - 1; i >= 0; i -= 1) {
    if (sessions >= ms[i].target_weekly_sessions) {
      currentIdx = i;
      break;
    }
  }
  const current = ms[currentIdx];
  const nextIdx = Math.min(currentIdx + 1, ms.length - 1);
  const next = ms[nextIdx];
  const progress = next.target_weekly_sessions > 0
    ? Math.min((sessions / next.target_weekly_sessions) * 100, 100)
    : 100;

  const monthlyPageViews = views * 4.3;
  const cpmTable = current.monetization === 'adsense-only'
    ? benchmarks.adsense_cpm_eur : benchmarks.moneytizer_cpm_eur;
  const cpm = cpmTable ? cpmTable.mid : 1;
  const estRevenue = ((monthlyPageViews / 1000) * cpm).toFixed(2);
  const organicShare = sessions > 0 ? (organicSessions / sessions) : 0;

  const kpis = current.kpis || {};
  const kpiResults = [];
  if (kpis.organic_share_min !== undefined) {
    kpiResults.push(evalKpi('Tráfico orgánico', organicShare, kpis.organic_share_min, 'gte'));
  }
  if (kpis.bounce_rate_max !== undefined) {
    kpiResults.push(evalKpi('Porcentaje de rebote', bounce, kpis.bounce_rate_max, 'lte'));
  }
  if (kpis.avg_duration_min_s !== undefined) {
    kpiResults.push(evalKpi('Duración media', `${duration.toFixed(0)}s`, `${kpis.avg_duration_min_s}s`, 'gte'));
  }
  if (kpis.chart_calculated_min !== undefined) {
    kpiResults.push(evalKpi('Cartas calculadas', chartCalc, kpis.chart_calculated_min, 'gte'));
  }
  if (kpis.interpretation_generated_min !== undefined) {
    kpiResults.push(evalKpi('Interpretaciones generadas', interpGen, kpis.interpretation_generated_min, 'gte'));
  }

  const capabilityRows = [
    ['GA4 unificado', signals.ga4Unified],
    ['Deploy selectivo', signals.deploySelective],
    ['Smoke SEO del cluster', signals.seoSmokeCluster],
    ['Autopatch rotatorio', signals.seoAutopatchRotatory],
    ['Reporting GSC por cluster', signals.gscClusterReporting],
    ['Envío de sitemap por API', signals.gscSitemapSubmit],
    ['Exclusión de tráfico interno', signals.internalTrafficOptOut],
    ['Media kit /publicidad', signals.clusterMediaKits],
    ['Recirculación interna por intención', signals.clusterRecirculation && signals.clusterSuiteEntrypoint],
    ['Slots premium por site', signals.premiumSlotsBySite],
    ['Cobertura long-tail', signals.longTailCoverage],
  ];

  const nextActions = Array.isArray(next.actions)
    ? next.actions.map((label) => ({ label, ...actionStatus(label, signals, gscVerifiedSiteCount) }))
    : [];

  const lines = [
    '### 🚀 Progreso de hitos de crecimiento',
    '',
    '| | Estado |',
    '|---|--------|',
    `| Etapa actual | **${current.id}: ${current.name}** |`,
    `| Siguiente hito | **${next.id}: ${next.name}** (${next.target_weekly_sessions} sesiones/semana) |`,
    `| Progreso | \`${progressBar(progress)}\` ${progress.toFixed(1)}% |`,
    `| Sesiones semanales | **${sessions}** |`,
    `| Monetización | ${current.monetization} |`,
    `| Ingreso mensual estimado | ~€${estRevenue} (${cpm}€ CPM) |`,
    '',
    '#### Señales de capacidad del cluster',
    '| Señal | Estado |',
    '|-------|--------|',
    ...capabilityRows.map(([label, ok]) => `| ${label} | ${ok ? '✅' : '⚠️'} |`),
    `| Páginas HTML públicas | ${signals.totalHtmlPages} |`,
    `| Propiedades GSC verificadas | ${gscVerifiedSiteCount}/${signals.siteCount} |`,
    '',
  ];

  if (kpiResults.length > 0) {
    lines.push('#### Salud de KPIs');
    lines.push('| KPI | Actual | Objetivo | Estado |');
    lines.push('|-----|--------|----------|--------|');
    lines.push(...kpiResults);
    lines.push('');
  }

  lines.push('#### Calidad de medición');
  lines.push('| Control | Estado |');
  lines.push('|---------|--------|');
  lines.push(`| Opt-out de tráfico interno | ${signals.internalTrafficOptOut ? `✅ ${signals.ga4OptOutPages}/${signals.ga4TaggedPages} páginas GA4 cubiertas` : `⚠️ ${signals.ga4OptOutPages}/${signals.ga4TaggedPages} páginas GA4 cubiertas`} |`);
  lines.push('| Línea base limpia | Desde que cada navegador interno abra `?analytics_optout=1` |');
  lines.push('');
  lines.push('> Los datos previos pueden incluir visitas propias o de revisión. Para evaluar tracción real, compara los próximos 7 días después de activar el opt-out en tus navegadores/dispositivos habituales.');
  lines.push('');

  if (nextActions.length > 0) {
    lines.push(`#### 📋 Siguientes acciones (${next.id}: ${next.name})`);
    for (const action of nextActions) {
      lines.push(`- [${action.done ? 'x' : ' '}] ${action.label} — ${action.evidence}`);
    }
    lines.push('');
  }

  if (currentIdx > 0 && sessions >= current.target_weekly_sessions &&
      sessions < current.target_weekly_sessions * 1.2) {
    lines.push(`> 🎉 **Milestone ${current.id} alcanzado.** Has superado ${current.target_weekly_sessions} sessions/week.`);
    lines.push('');
  }

  console.log(lines.join('\n'));

  const previousSerialized = JSON.stringify(milestones);

  for (const milestone of ms) {
    const newStatus = sessions >= milestone.target_weekly_sessions
      ? 'achieved'
      : milestone.id === current.id ? 'in-progress' : 'pending';

    milestone.status = newStatus;
    if (Array.isArray(milestone.actions)) {
      const evaluated = milestone.actions.map((label) => ({
        label,
        ...actionStatus(label, signals, gscVerifiedSiteCount),
      }));
      milestone.auto = {
        completed_actions: evaluated.filter((item) => item.done).length,
        total_actions: evaluated.length,
        actions: evaluated,
      };
    }
  }

  milestones.auto = {
    last_eval: new Date().toISOString().slice(0, 10),
    current_stage_id: current.id,
    next_stage_id: next.id,
    weekly_metrics: {
      sessions,
      users,
      views,
      organic_sessions: organicSessions,
      organic_share: Number(organicShare.toFixed(4)),
      bounce_rate: Number(bounce.toFixed(4)),
      avg_duration_s: Number(duration.toFixed(1)),
      chart_calculated: chartCalc,
      interpretation_generated: interpGen,
    },
    capability_signals: {
      ga4_unified: signals.ga4Unified,
      deploy_selective: signals.deploySelective,
      seo_smoke_cluster: signals.seoSmokeCluster,
      seo_autopatch_rotatory: signals.seoAutopatchRotatory,
      gsc_cluster_reporting: signals.gscClusterReporting,
      gsc_sitemap_submit: signals.gscSitemapSubmit,
      gsc_verified_site_count: gscVerifiedSiteCount,
      internal_traffic_optout: signals.internalTrafficOptOut,
      ga4_tagged_pages: signals.ga4TaggedPages,
      ga4_optout_pages: signals.ga4OptOutPages,
      cluster_media_kits: signals.clusterMediaKits,
      cluster_recirculation: signals.clusterRecirculation && signals.clusterSuiteEntrypoint,
      premium_slots_by_site: signals.premiumSlotsBySite,
      total_html_pages: signals.totalHtmlPages,
      long_tail_coverage: signals.longTailCoverage,
      eeat_schema_coverage: signals.eeatSchemasPresent,
    },
    site_page_counts: signals.publicHtmlBySite,
  };

  const nextSerialized = JSON.stringify(milestones);
  if (previousSerialized !== nextSerialized) {
    milestones.updated = new Date().toISOString().slice(0, 10);
    fs.writeFileSync(MILESTONES_PATH, JSON.stringify(milestones, null, 2) + '\n', 'utf8');
  }
}

main();
