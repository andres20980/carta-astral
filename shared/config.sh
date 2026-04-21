#!/usr/bin/env bash
# Shared configuration for all esoteric cluster sites
# Source this file from any site generator script

# — AdSense (same account for all sites)
ADSENSE_PUB="ca-pub-9368517395014039"

# — GA4 (single cluster-wide property + cross-domain linker)
CLUSTER_GA4_ID="G-DEWMQ73FH5"
declare -A GA4_IDS=(
  [carta-astral]="$CLUSTER_GA4_ID"
  [compatibilidad-signos]="$CLUSTER_GA4_ID"
  [tarot-del-dia]="$CLUSTER_GA4_ID"
  [calcular-numerologia]="$CLUSTER_GA4_ID"
  [horoscopo-de-hoy]="$CLUSTER_GA4_ID"
)

# — Domains
declare -A DOMAINS=(
  [carta-astral]="carta-astral-gratis.es"
  [compatibilidad-signos]="compatibilidad-signos.es"
  [tarot-del-dia]="tarot-del-dia.es"
  [calcular-numerologia]="calcular-numerologia.es"
  [horoscopo-de-hoy]="horoscopo-de-hoy.es"
)

declare -A TOOL_TYPES=(
  [carta-astral]="astrology_chart"
  [compatibilidad-signos]="compatibility"
  [tarot-del-dia]="tarot"
  [calcular-numerologia]="numerology"
  [horoscopo-de-hoy]="daily_horoscope"
)

declare -a CLUSTER_SITE_KEYS=(
  "carta-astral"
  "compatibilidad-signos"
  "tarot-del-dia"
  "calcular-numerologia"
  "horoscopo-de-hoy"
)

declare -a TRACKING_DOMAINS=(
  "carta-astral-gratis.es"
  "compatibilidad-signos.es"
  "tarot-del-dia.es"
  "calcular-numerologia.es"
  "horoscopo-de-hoy.es"
)

declare -A GSC_SITE_URLS=(
  [carta-astral]="sc-domain:carta-astral-gratis.es"
  [compatibilidad-signos]="sc-domain:compatibilidad-signos.es"
  [tarot-del-dia]="sc-domain:tarot-del-dia.es"
  [calcular-numerologia]="sc-domain:calcular-numerologia.es"
  [horoscopo-de-hoy]="sc-domain:horoscopo-de-hoy.es"
)

gsc_site_url_for() {
  local site_key="$1"
  echo "${GSC_SITE_URLS[$site_key]}"
}

sitemap_url_for() {
  local site_key="$1"
  echo "https://${DOMAINS[$site_key]}/sitemap.xml"
}

canonical_host_redirect_script() {
  local domain="$1"
  cat <<EOF
  <script>if(location.hostname==='www.${domain}'||location.hostname.endsWith('.web.app'))location.replace('https://${domain}'+location.pathname+location.search);</script>
EOF
}

# — Shared brand
BRAND_FONTS="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;700&family=Inter:wght@300;400;500;600&display=swap"
CONTACT_EMAIL="publicidad@carta-astral-gratis.es"

# — CSS Variables (same palette across all sites)
CSS_VARS=':root{--bg:#faf8f5;--surface:#fff;--border:#e8e0d8;--text:#2d2a26;--muted:#7a7268;--accent:#7c3aed;--accent2:#c084fc;--gold:#d4a017;--gradient:linear-gradient(135deg,#7c3aed 0%,#c084fc 50%,#d4a017 100%);--shadow:0 2px 12px rgba(124,58,237,.08)}'

# — Cross-link network (all sites link to each other)
declare -A CROSSLINKS=(
  [carta-astral]="Carta Astral Gratis"
  [compatibilidad-signos]="Compatibilidad de Signos"
  [tarot-del-dia]="Tarot del Día"
  [calcular-numerologia]="Calcular Numerología"
  [horoscopo-de-hoy]="Horóscopo de Hoy"
)

# — Commercial / direct advertising copy
declare -A SITE_COMMERCIAL_HOOK=(
  [carta-astral]="Una audiencia de alta intención interesada en astrología, autoconocimiento y bienestar."
  [compatibilidad-signos]="Una audiencia que llega con intención clara de resolver dudas sobre amor, pareja y afinidad."
  [tarot-del-dia]="Una audiencia que busca guía inmediata, lectura espiritual y productos del nicho esotérico."
  [calcular-numerologia]="Una audiencia que quiere respuestas personales, formación y herramientas de crecimiento interior."
  [horoscopo-de-hoy]="Una audiencia recurrente que vuelve a diario para consultar amor, trabajo y salud."
)

declare -A SITE_COMMERCIAL_BRANDS=(
  [carta-astral]="consultas astrológicas, tarot profesional, tiendas esotéricas, cursos y bienestar"
  [compatibilidad-signos]="aplicaciones de citas, acompañamiento de pareja, joyería, regalos personalizados y bienestar emocional"
  [tarot-del-dia]="consultas de tarot, cursos, mazos, velas, incienso, rituales y membresías espirituales"
  [calcular-numerologia]="escuelas holísticas, libros, consultoría espiritual, membresías de pago y herramientas formativas"
  [horoscopo-de-hoy]="tarot, astrología, bienestar, tiendas espirituales, suscripciones y recomendaciones afiliadas"
)

declare -A SITE_COMMERCIAL_CONTEXT=(
  [carta-astral]="aparece a lo largo del flujo de cálculo y en puntos de máxima atención de la carta natal"
  [compatibilidad-signos]="aparece junto a comparativas de signos y combinaciones muy buscadas por tráfico orgánico"
  [tarot-del-dia]="aparece junto a la tirada interactiva y al contenido estable de arcanos"
  [calcular-numerologia]="aparece junto al cálculo del número de vida y a fichas de fuerte intención educativa"
  [horoscopo-de-hoy]="aparece junto a predicciones diarias y fichas de signos con consumo recurrente"
)

# Helper: generate cross-link footer HTML for a given site key
crosslink_footer() {
  local current="$1"
  local html='<div class="network">Nuestras herramientas: '
  local first=true
  for key in carta-astral compatibilidad-signos tarot-del-dia calcular-numerologia horoscopo-de-hoy; do
    [[ "$key" == "$current" ]] && continue
    local domain="${DOMAINS[$key]}"
    local name="${CROSSLINKS[$key]}"
    $first || html+=" · "
    html+="<a href=\"https://${domain}/\" rel=\"noopener\" data-link-context=\"network_footer\" data-destination-site=\"${key}\" data-destination-domain=\"${domain}\">${name}</a>"
    first=false
  done
  html+='</div>'
  echo "$html"
}

ga4_head_snippet() {
  local measurement_id="$1"
  local site_key="${2:-cluster}"
  local page_type="${3:-page}"
  local content_group="${4:-content}"
  local entity_slug="${5:-}"
  local domains_js=""
  local site_map_js=""
  local domain
  local key
  for domain in "${TRACKING_DOMAINS[@]}"; do
    domains_js+="'${domain}',"
  done
  domains_js="${domains_js%,}"
  for key in "${CLUSTER_SITE_KEYS[@]}"; do
    site_map_js+="'${DOMAINS[$key]}':'${key}',"
  done
  site_map_js="${site_map_js%,}"

  cat <<EOF
  <script>
    (function(){
      const measurementId='${measurement_id}';
      const storageKey='astro_cluster_analytics_optout';
      let optedOut=false;
      try{
        const params=new URLSearchParams(location.search);
        const value=params.get('analytics_optout');
        if(value==='1'||value==='true')localStorage.setItem(storageKey,'1');
        if(value==='0'||value==='false')localStorage.removeItem(storageKey);
        optedOut=localStorage.getItem(storageKey)==='1';
      }catch(e){}
      window.clusterAnalyticsOptedOut=optedOut;
      window['ga-disable-'+measurementId]=window.clusterAnalyticsOptedOut;
    })();
  </script>
  <script async src="https://www.googletagmanager.com/gtag/js?id=${measurement_id}"></script>
  <script>
    window.dataLayer=window.dataLayer||[];
    function gtag(){dataLayer.push(arguments);}
    window.clusterSitesByDomain={${site_map_js}};
    window.clusterAnalyticsMeta={
      cluster_name:'astro-cluster',
      site_key:'${site_key}',
      site_domain:'${DOMAINS[$site_key]}',
      tool_type:'${TOOL_TYPES[$site_key]}',
      page_type:'${page_type}',
      content_group:'${content_group}',
      entity_slug:'${entity_slug}'
    };
    window.clusterTrack=function(eventName,params){
      if(window.clusterAnalyticsOptedOut)return;
      const payload=Object.assign({},window.clusterAnalyticsMeta,params||{});
      Object.keys(payload).forEach(key=>{
        if(payload[key]===''||payload[key]===null||payload[key]===undefined)delete payload[key];
      });
      payload.transport_type='beacon';
      gtag('event',eventName,payload);
    };
    gtag('js',new Date());
    gtag('config','${measurement_id}',{
      send_page_view:false,
      linker:{domains:[${domains_js}]}
    });
    window.clusterTrack('page_view',{
      page_title:document.title,
      page_location:location.href,
      page_path:location.pathname,
      page_hostname:location.hostname,
      page_referrer:document.referrer||undefined
    });
    document.addEventListener('click',function(event){
      const anchor=event.target.closest('a[href]');
      if(!anchor||anchor.dataset.analyticsIgnore==='1')return;
      const rawHref=anchor.getAttribute('href')||'';
      if(!rawHref||rawHref.startsWith('#')||rawHref.startsWith('mailto:')||rawHref.startsWith('tel:'))return;
      let url;
      try{url=new URL(anchor.href,location.href);}catch{return;}
      const normalizeHost=host=>(host||'').replace(/^www\./,'');
      const destinationDomain=normalizeHost(url.hostname);
      const currentDomain=normalizeHost(location.hostname);
      const destinationSite=anchor.dataset.destinationSite||window.clusterSitesByDomain[destinationDomain]||'';
      const linkText=(anchor.textContent||'').replace(/\s+/g,' ').trim().slice(0,120);
      const linkContext=anchor.dataset.linkContext||'';
      const adSlot=anchor.dataset.adSlot||'';
      if(anchor.matches('.ad-ph,.ad-link,[data-ad-slot]')||url.pathname==='/publicidad'){
        window.clusterTrack('advertiser_cta_click',{
          link_url:url.href,
          link_text:linkText,
          link_context:linkContext||'advertiser_cta',
          ad_slot:adSlot||'direct_advertiser_cta'
        });
        return;
      }
      if(destinationSite&&destinationDomain!==currentDomain){
        window.clusterTrack('internal_tool_click',{
          link_url:url.href,
          link_text:linkText,
          link_context:linkContext||'cluster_crosslink',
          destination_site:destinationSite,
          destination_domain:destinationDomain
        });
      }
    },{capture:true});
  </script>
EOF
}

ad_css() {
  cat <<'EOF'
    .ad-h{margin:1.25rem 0}
    .ad-ph{display:flex;align-items:center;justify-content:center;text-decoration:none;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,#f9f5ff 0%,#fef9ee 100%);box-shadow:var(--shadow);padding:1rem;transition:transform .2s,box-shadow .2s,border-color .2s;text-align:center;color:var(--text)}
    .ad-ph:hover{transform:translateY(-2px);box-shadow:0 10px 26px rgba(124,58,237,.14);border-color:rgba(124,58,237,.28)}
    .ad-ph-h{min-height:122px;flex-direction:column;gap:.32rem}
    .ad-kicker{font-size:.63rem;letter-spacing:.08em;text-transform:uppercase;font-weight:700;color:var(--accent)}
    .ad-icon{font-size:1.5rem;line-height:1}
    .ad-label{font-family:'Playfair Display',serif;font-size:1.08rem;font-weight:700;line-height:1.25}
    .ad-copy{font-size:.82rem;line-height:1.6;color:var(--muted);max-width:560px}
    .ad-cta{display:inline-flex;align-items:center;justify-content:center;margin-top:.2rem;padding:.45rem .95rem;border-radius:999px;background:var(--accent);color:#fff;font-size:.76rem;font-weight:700}
    .ad-link{color:var(--accent);text-decoration:none;font-weight:600}
    .ad-link:hover{text-decoration:underline}
    @media(max-width:600px){
      .ad-ph-h{min-height:110px;padding:.9rem}
      .ad-label{font-size:.98rem}
      .ad-copy{font-size:.78rem}
    }
EOF
}

ad_block() {
  local icon="$1"
  local label="$2"
  local copy="$3"
  local cta="${4:-Ver espacios y tarifas →}"
  cat <<EOF
<div class="ad-h">
  <a class="ad-ph ad-ph-h" href="/publicidad" title="Anúnciate aquí" data-ad-slot="premium_direct_cta" data-link-context="ad_block">
    <span class="ad-kicker">Espacio publicitario destacado</span>
    <span class="ad-icon">${icon}</span>
    <span class="ad-label">${label}</span>
    <span class="ad-copy">${copy}</span>
    <span class="ad-cta">${cta}</span>
  </a>
</div>
EOF
}

footer_publicidad_line() {
  local current="$1"
  local name="${CROSSLINKS[$current]}"
  echo "<p style=\"margin-top:.6rem\"><a href=\"/publicidad\" class=\"ad-link\" data-ad-slot=\"footer_publicidad_cta\" data-link-context=\"footer_publicidad\">✦ Quiero anunciarme en ${name}: ver espacios y tarifas</a></p>"
}

cluster_css() {
  cat <<'EOF'
    .cluster-journey{margin:1.6rem 0;padding:1.35rem;border:1px solid var(--border);border-radius:18px;background:linear-gradient(135deg,#fff 0%,#f9f5ff 52%,#fef9ee 100%);box-shadow:var(--shadow)}
    .cluster-journey .cluster-kicker{display:inline-flex;align-items:center;gap:.45rem;font-size:.66rem;font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:var(--accent);margin-bottom:.5rem}
    .cluster-journey h2{margin-bottom:.45rem}
    .cluster-journey p{color:var(--muted);font-size:.9rem;line-height:1.7}
    .cluster-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:.9rem;margin-top:1rem}
    .cluster-card{display:block;padding:1rem 1rem 1.05rem;border-radius:14px;border:1px solid var(--border);background:rgba(255,255,255,.92);text-decoration:none;color:var(--text);box-shadow:0 8px 20px rgba(124,58,237,.08);transition:transform .18s,border-color .18s,box-shadow .18s}
    .cluster-card:hover{transform:translateY(-2px);border-color:rgba(124,58,237,.28);box-shadow:0 14px 28px rgba(124,58,237,.13)}
    .cluster-card .cluster-label{display:block;font-size:.7rem;font-weight:700;letter-spacing:.05em;text-transform:uppercase;color:var(--accent);margin-bottom:.2rem}
    .cluster-card .cluster-title{display:block;font-family:'Playfair Display',serif;font-size:1rem;margin-bottom:.28rem}
    .cluster-card .cluster-copy{display:block;font-size:.82rem;line-height:1.58;color:var(--muted)}
    .cluster-card .cluster-cta{display:inline-block;margin-top:.65rem;font-size:.8rem;font-weight:700;color:var(--accent)}
    .cluster-journey .cluster-note{margin-top:.8rem;font-size:.78rem;color:var(--muted)}
    @media(max-width:600px){
      .cluster-journey{padding:1.1rem}
      .cluster-grid{grid-template-columns:1fr}
    }
EOF
}

cluster_card() {
  local site_key="$1"
  local label="$2"
  local title="$3"
  local copy="$4"
  local cta="$5"
  local domain="${DOMAINS[$site_key]}"
cat <<EOF
<a class="cluster-card" href="https://${domain}/" data-link-context="cluster_recirculation" data-destination-site="${site_key}" data-destination-domain="${domain}">
  <span class="cluster-label">${label}</span>
  <span class="cluster-title">${title}</span>
  <span class="cluster-copy">${copy}</span>
  <span class="cluster-cta">${cta}</span>
</a>
EOF
}

cluster_recirculation_block() {
  local current="$1"
  local heading="También te puede interesar"
  local intro="Si quieres seguir profundizando, aquí tienes otras herramientas relacionadas para conocer mejor tu situación."
  local cards=""

  case "$current" in
    carta-astral)
      cards+=$(cluster_card "compatibilidad-signos" "Relaciones" "Compatibilidad de Signos" "Descubre cómo encajan dos signos y consulta combinaciones concretas en amor, amistad y convivencia." "Ver combinaciones →")
      cards+=$(cluster_card "tarot-del-dia" "Guía rápida" "Tarot del Día" "Haz una tirada breve si buscas una orientación inmediata para el momento que estás viviendo." "Hacer una tirada →")
      cards+=$(cluster_card "horoscopo-de-hoy" "Predicción diaria" "Horóscopo de Hoy" "Consulta tu energía del día en amor, trabajo y bienestar según tu signo." "Leer el horóscopo →")
      ;;
    compatibilidad-signos)
      cards+=$(cluster_card "carta-astral" "Profundizar" "Carta Astral Gratis" "Completa la compatibilidad con Venus, Luna, Marte y ascendente usando tus datos de nacimiento." "Calcular carta astral →")
      cards+=$(cluster_card "horoscopo-de-hoy" "Seguimiento" "Horóscopo de Hoy" "Mira el clima del día para tu signo y suma una lectura rápida sobre amor, trabajo y salud." "Ver predicciones →")
      cards+=$(cluster_card "tarot-del-dia" "Respuesta rápida" "Tarot del Día" "Si necesitas una señal inmediata, haz una tirada corta con una lectura simbólica fácil de entender." "Tirar las cartas →")
      ;;
    tarot-del-dia)
      cards+=$(cluster_card "carta-astral" "Capa profunda" "Carta Astral Gratis" "Amplía la lectura del tarot con una visión más completa de tu personalidad, ciclos y relaciones." "Ir a mi carta →")
      cards+=$(cluster_card "horoscopo-de-hoy" "Rutina" "Horóscopo de Hoy" "Consulta tu signo para completar la lectura con una predicción breve del día." "Leer mi signo →")
      cards+=$(cluster_card "compatibilidad-signos" "Amor y pareja" "Compatibilidad de Signos" "Compara dos signos si tu tirada toca temas de relación, afinidad o decisiones en pareja." "Comparar signos →")
      ;;
    calcular-numerologia)
      cards+=$(cluster_card "carta-astral" "Perfil completo" "Carta Astral Gratis" "Combina tu número de vida con planetas, casas y ascendente para obtener una lectura más completa." "Completar análisis →")
      cards+=$(cluster_card "compatibilidad-signos" "Vínculos" "Compatibilidad de Signos" "Explora afinidades entre signos si quieres llevar la interpretación a relaciones y conexiones personales." "Explorar afinidad →")
      cards+=$(cluster_card "horoscopo-de-hoy" "Predicción diaria" "Horóscopo de Hoy" "Añade una lectura ligera del día para complementar tu perfil personal." "Ver hoy →")
      ;;
    horoscopo-de-hoy)
      cards+=$(cluster_card "carta-astral" "Personalizado" "Carta Astral Gratis" "Pasa de una predicción general a una lectura personalizada con fecha, hora y lugar de nacimiento." "Calcular ahora →")
      cards+=$(cluster_card "compatibilidad-signos" "Relaciones" "Compatibilidad de Signos" "Consulta la afinidad entre dos signos si quieres entender mejor una relación o una persona concreta." "Ver compatibilidad →")
      cards+=$(cluster_card "tarot-del-dia" "Consulta breve" "Tarot del Día" "Haz una tirada rápida si buscas una señal adicional para tomar una decisión hoy." "Abrir tirada →")
      ;;
    *)
      cards+=$(cluster_card "carta-astral" "Astrología" "Carta Astral Gratis" "Descubre tu carta natal completa con una interpretación personalizada." "Abrir →")
      cards+=$(cluster_card "compatibilidad-signos" "Afinidad" "Compatibilidad de Signos" "Compara dos signos y explora cómo encajan en distintos planos." "Abrir →")
      cards+=$(cluster_card "horoscopo-de-hoy" "Predicción diaria" "Horóscopo de Hoy" "Lee tu horóscopo del día y consulta la energía de tu signo." "Abrir →")
      ;;
  esac

  cat <<EOF
<section class="cluster-journey">
  <div class="cluster-kicker">✦ Más herramientas para ti</div>
  <h2>${heading}</h2>
  <p>${intro}</p>
  <div class="cluster-grid">
    ${cards}
  </div>
  <p class="cluster-note">Explora otras herramientas del grupo si quieres ampliar la lectura desde otro ángulo.</p>
</section>
EOF
}

gen_publicidad_page() {
  local current="$1"
  local public_dir="$2"
  local name="${CROSSLINKS[$current]}"
  local domain="${DOMAINS[$current]}"
  local hook="${SITE_COMMERCIAL_HOOK[$current]}"
  local brands="${SITE_COMMERCIAL_BRANDS[$current]}"
  local context="${SITE_COMMERCIAL_CONTEXT[$current]}"

  cat > "${public_dir}/publicidad.html" <<EOF
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Publicidad en ${name} - Dosier para anunciantes</title>
  <meta name="description" content="Anuncia tu marca en ${domain} o en toda la red esotérica. ${hook} Espacios destacados, patrocinios directos y formatos flexibles.">
  <link rel="canonical" href="https://${domain}/publicidad">
  <meta property="og:title" content="Publicidad en ${name}">
  <meta property="og:description" content="${hook}">
  <meta property="og:type" content="website">
  <meta property="og:url" content="https://${domain}/publicidad">
  <meta property="og:locale" content="es_ES">
  <meta name="robots" content="index, follow">
  <link rel="preconnect" href="https://fonts.googleapis.com" crossorigin>
  <link href="${BRAND_FONTS}" rel="stylesheet" media="print" onload="this.media='all'">
  <noscript><link href="${BRAND_FONTS}" rel="stylesheet"></noscript>
$(canonical_host_redirect_script "$domain")
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"WebPage","name":"Publicidad en ${name}","url":"https://${domain}/publicidad","description":"Dosier comercial y espacios destacados para anunciantes en ${domain}","inLanguage":"es"}
  </script>
  <style>
    ${CSS_VARS}
    *{margin:0;padding:0;box-sizing:border-box}
    body{font-family:'Inter',system-ui,sans-serif;background:var(--bg);color:var(--text);line-height:1.6}
    .wrap{max-width:840px;margin:0 auto;padding:0 1.5rem 3rem}
    nav{text-align:center;padding:1.1rem 1rem;border-bottom:1px solid var(--border)}
    nav a{color:var(--accent);text-decoration:none;font-weight:600;font-size:.88rem}
    .hero{text-align:center;padding:2.8rem 0 1.6rem}
    .hero h1{font-family:'Playfair Display',serif;font-size:2rem;background:var(--gradient);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
    .hero p{max-width:620px;margin:.8rem auto 0;color:var(--muted);font-size:.98rem}
    section{margin:2rem 0}
    section h2{font-family:'Playfair Display',serif;font-size:1.35rem;margin-bottom:.8rem}
    section p,section li{color:var(--muted);font-size:.92rem;line-height:1.7}
    .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:1rem;margin-top:1rem}
    .card{background:var(--surface);border:1px solid var(--border);border-radius:14px;padding:1.2rem;box-shadow:var(--shadow)}
    .card h3{font-size:.95rem;margin-bottom:.25rem}
    .card .icon{font-size:1.5rem;margin-bottom:.45rem}
    .slots{display:grid;gap:1rem;margin-top:1rem}
    .slot{background:var(--surface);border:1px solid var(--border);border-radius:14px;padding:1.2rem;box-shadow:var(--shadow)}
    .slot h3{font-family:'Playfair Display',serif;font-size:1rem;margin-bottom:.25rem}
    .slot .price{margin-top:.45rem;font-weight:700;color:var(--accent)}
    table{width:100%;border-collapse:collapse;background:var(--surface);border:1px solid var(--border);border-radius:14px;overflow:hidden;box-shadow:var(--shadow);font-size:.88rem}
    th,td{padding:.8rem 1rem;border-top:1px solid var(--border);text-align:left}
    thead th{border-top:none;background:#f9f5ff;color:var(--accent);font-size:.76rem;text-transform:uppercase;letter-spacing:.05em}
    .cta{margin-top:2rem;padding:2rem 1.2rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,#f9f5ff 0%,#fef9ee 100%);text-align:center}
    .cta h2{margin-bottom:.5rem}
    .btn{display:inline-block;margin-top:.9rem;padding:.8rem 1.6rem;border-radius:999px;background:var(--accent);color:#fff;text-decoration:none;font-weight:700}
    footer{text-align:center;padding:2rem 0 0;color:var(--muted);font-size:.78rem}
    footer a{color:var(--accent);text-decoration:none}
    @media(max-width:600px){
      .hero h1{font-size:1.6rem}
      table{font-size:.82rem}
      th,td{padding:.7rem}
    }
  </style>
</head>
<body>
<nav><a href="/">← Volver a ${name}</a></nav>
<div class="wrap">
  <div class="hero">
    <h1>Dosier comercial - Publicidad</h1>
    <p>${hook} Si vendes ${brands}, estos espacios te ponen delante de una audiencia contextual. Puedes reservar una posición en este sitio o comprar presencia estática en toda la red.</p>
  </div>

  <section>
    <h2>Qué tipo de campañas encajan</h2>
    <p>Estos espacios están pensados para marcas que quieren aparecer en páginas con intención clara: usuarios que calculan una carta, consultan una compatibilidad, revisan su horóscopo, hacen una tirada o buscan su número de vida. La visibilidad no depende de una subasta automática: se pacta ubicación, duración y mensaje antes de publicar.</p>
    <p>Priorizamos anunciantes que aporten algo razonable al contexto del sitio: consultas, formación, libros, herramientas, bienestar, productos digitales o servicios relacionados. No aceptamos creatividades engañosas, promesas garantizadas ni mensajes que puedan confundirse con el contenido editorial.</p>
  </section>

  <section>
    <h2>Por qué anunciarte aquí</h2>
    <div class="grid">
      <div class="card">
        <div class="icon">🎯</div>
        <h3>Intención alta</h3>
        <p>El usuario no llega por curiosidad genérica: entra buscando una respuesta concreta y consume contenido con foco.</p>
      </div>
      <div class="card">
        <div class="icon">🧩</div>
        <h3>Contexto relevante</h3>
        <p>Tu marca ${context}, lo que mejora recuerdo, afinidad y clics frente a espacios publicitarios genéricos.</p>
      </div>
      <div class="card">
        <div class="icon">💸</div>
        <h3>Venta directa</h3>
        <p>El patrocinio directo tiene prioridad comercial: texto aprobado, ubicación fija y presencia contextual sin depender de subastas automáticas.</p>
      </div>
      <div class="card">
        <div class="icon">📦</div>
        <h3>Compra por red</h3>
        <p>Una misma creatividad puede aparecer en las 5 herramientas para cubrir astrología, tarot, numerología, horóscopo y compatibilidad.</p>
      </div>
    </div>
  </section>

  <section>
    <h2>Espacios disponibles</h2>
    <div class="slots">
      <div class="slot">
        <h3>Banner superior</h3>
        <p>Primera impresión bajo la cabecera. Ideal para notoriedad de marca y campañas tácticas.</p>
        <div class="price">25 EUR / mes</div>
      </div>
      <div class="slot">
        <h3>Banner en contenido</h3>
        <p>Ubicación destacada en el punto de mayor atención. Buen equilibrio entre visibilidad e interacción.</p>
        <div class="price">30 EUR / mes</div>
      </div>
      <div class="slot">
        <h3>Banner previo al pie de página</h3>
        <p>Impacto adicional para usuarios que terminan la lectura y ya han mostrado interés real.</p>
        <div class="price">15 EUR / mes</div>
      </div>
      <div class="slot">
        <h3>Patrocinio destacado</h3>
        <p>Texto comercial adaptado al nicho, recomendación editorial o integración de afiliación bajo solicitud.</p>
        <div class="price">Desde 35 EUR / mes</div>
      </div>
    </div>
  </section>

  <section>
    <h2>Tarifas orientativas</h2>
    <table>
      <thead>
        <tr><th>Formato</th><th>Objetivo</th><th>Precio</th></tr>
      </thead>
      <tbody>
        <tr><td>Banner superior</td><td>Máxima visibilidad</td><td>25 EUR / mes</td></tr>
        <tr><td>Banner en contenido</td><td>Clics y afinidad</td><td>30 EUR / mes</td></tr>
        <tr><td>Banner previo al pie</td><td>Frecuencia extra</td><td>15 EUR / mes</td></tr>
        <tr><td>Paquete del sitio</td><td>Superior + contenido</td><td>45 EUR / mes</td></tr>
        <tr><td>Exclusividad del sitio</td><td>3 espacios + exclusividad del dominio</td><td>75 EUR / mes</td></tr>
        <tr><td>Paquete de la red</td><td>Presencia estática en 5 dominios</td><td>120 EUR / mes</td></tr>
        <tr><td>Exclusividad de la red</td><td>Espacios destacados + exclusividad de categoría</td><td>250 EUR / mes</td></tr>
      </tbody>
    </table>
    <p style="margin-top:.75rem">Datos de tráfico, capturas de GA4, creatividades admitidas, paquetes trimestrales y opciones de patrocinio ampliado disponibles bajo solicitud.</p>
    <p style="margin-top:.75rem">Los formatos se venden como espacios estáticos: texto, imagen ligera o enlace patrocinado integrado con el contexto de la página. Antes de publicar revisamos que la página de destino, el mensaje y la categoría encajen con la audiencia para proteger tanto al anunciante como la experiencia del usuario.</p>
    <p style="margin-top:.75rem">La venta directa nos permite evitar anuncios automáticos poco relevantes y priorizar marcas que aporten valor real: consultas profesionales, formación seria, productos de bienestar, herramientas de autoconocimiento y servicios afines. Si una campaña no encaja con la temática o puede generar desconfianza, no la publicamos.</p>
    <p style="margin-top:.75rem">Tratamos la red como un único cluster comercial: se puede reservar un dominio concreto, combinar varias webs o plantear presencia en las cinco propiedades con un mismo mensaje adaptado a cada intención de búsqueda.</p>
  </section>

  <section>
    <h2>Qué necesitamos para publicar</h2>
    <ul>
      <li>Marca, web de destino y objetivo de la campaña.</li>
      <li>Texto breve, imagen ligera o propuesta de patrocinio contextual.</li>
      <li>Duración prevista, dominio preferido y categoría que quieres ocupar.</li>
      <li>Confirmación de que la página de destino es clara, segura y coherente con el mensaje anunciado.</li>
    </ul>
    <p style="margin-top:.75rem">Una vez acordado el espacio, revisamos la creatividad, la publicamos de forma estática y podemos preparar una propuesta para ampliar presencia en otros dominios de la red si los datos acompañan.</p>
  </section>

  <div class="cta">
    <h2>Reservar un espacio</h2>
    <p>Escribe con tu marca, objetivo, creatividad o página de destino y te devolvemos propuesta, disponibilidad, paquetes del sitio y opciones para la red sin intermediarios.</p>
    <a class="btn" href="mailto:${CONTACT_EMAIL}?subject=Publicidad%20${domain}%20o%20red&body=Hola%2C%0A%0AMe%20interesa%20anunciarme%20en%20${domain}%20o%20en%20la%20red.%0A%0APaquete%20que%20me%20interesa%3A%0APeriodo%3A%0AWeb%2Fmarca%3A%0A%0AGracias">Contactar por correo</a>
  </div>

  <footer>
    <p>© $(date +%Y) ${name}</p>
    <p style="margin-top:.4rem"><a href="/">Inicio</a> · <a href="/privacy">Privacidad</a> · <a href="/terms">Términos</a></p>
  </footer>
</div>
</body>
</html>
EOF
}
