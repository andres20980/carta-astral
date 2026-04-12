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

# — Shared brand
BRAND_FONTS="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;700&family=Inter:wght@300;400;500;600&display=swap"
CONTACT_EMAIL="contacto@carta-astral-gratis.es"

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
  [carta-astral]="Una audiencia de alta intencion interesada en astrologia, autoconocimiento y bienestar."
  [compatibilidad-signos]="Una audiencia que llega con intencion clara de resolver dudas sobre amor, pareja y afinidad."
  [tarot-del-dia]="Una audiencia que busca guia inmediata, lectura espiritual y productos del nicho esoterico."
  [calcular-numerologia]="Una audiencia que quiere respuestas personales, formacion y herramientas de crecimiento interior."
  [horoscopo-de-hoy]="Una audiencia recurrente que vuelve a diario para consultar amor, trabajo y salud."
)

declare -A SITE_COMMERCIAL_BRANDS=(
  [carta-astral]="consultas astrologicas, tarot profesional, ecommerce esoterico, cursos y bienestar"
  [compatibilidad-signos]="apps de citas, coaching de pareja, joyeria, regalos personalizados y bienestar emocional"
  [tarot-del-dia]="consultas de tarot, cursos, mazos, velas, incienso, rituales y membresias espirituales"
  [calcular-numerologia]="escuelas holisticas, libros, consultoria espiritual, membresias premium y software formativo"
  [horoscopo-de-hoy]="tarot, astrologia, bienestar, ecommerce espiritual, suscripciones y recomendaciones afiliadas"
)

declare -A SITE_COMMERCIAL_CONTEXT=(
  [carta-astral]="aparece a lo largo del flujo de calculo y en puntos de maxima atencion de la carta natal"
  [compatibilidad-signos]="aparece junto a comparativas de signos y combinaciones muy buscadas por trafico SEO"
  [tarot-del-dia]="aparece junto a la tirada interactiva y al contenido evergreen de arcanos"
  [calcular-numerologia]="aparece junto al calculo del numero de vida y a fichas de fuerte intencion educativa"
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
    html+="<a href=\"https://${domain}/\" rel=\"noopener\">${name}</a>"
    first=false
  done
  html+='</div>'
  echo "$html"
}

ga4_head_snippet() {
  local measurement_id="$1"
  local domains_js=""
  local domain
  for domain in "${TRACKING_DOMAINS[@]}"; do
    domains_js+="'${domain}',"
  done
  domains_js="${domains_js%,}"

  cat <<EOF
  <script async src="https://www.googletagmanager.com/gtag/js?id=${measurement_id}"></script>
  <script>window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag('js',new Date());gtag('config','${measurement_id}',{linker:{domains:[${domains_js}]}});</script>
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
  local cta="${4:-Ver espacios y tarifas ->}"
  cat <<EOF
<div class="ad-h">
  <a class="ad-ph ad-ph-h" href="/publicidad" title="Anunciate aqui">
    <span class="ad-kicker">Espacio publicitario premium</span>
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
  echo "<p style=\"margin-top:.6rem\"><a href=\"/publicidad\" class=\"ad-link\">✦ Quiero anunciarme en ${name}: ver espacios y tarifas</a></p>"
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
  <title>Publicidad en ${name} - Media Kit para Anunciantes</title>
  <meta name="description" content="Anuncia tu marca en ${domain}. ${hook} Espacios premium, patrocinios directos y formatos flexibles para anunciantes del nicho.">
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
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"WebPage","name":"Publicidad en ${name}","url":"https://${domain}/publicidad","description":"Media kit y espacios premium para anunciantes en ${domain}","inLanguage":"es"}
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
    <h1>Media Kit - Publicidad</h1>
    <p>${hook} Si vendes ${brands}, este inventario te pone delante de una audiencia contextual y ya predispuesta a convertir.</p>
  </div>

  <section>
    <h2>Por que anunciarte aqui</h2>
    <div class="grid">
      <div class="card">
        <div class="icon">🎯</div>
        <h3>Intencion alta</h3>
        <p>El usuario no llega por curiosidad generica: entra buscando una respuesta concreta y consume contenido con foco.</p>
      </div>
      <div class="card">
        <div class="icon">🧩</div>
        <h3>Contexto relevante</h3>
        <p>Tu marca ${context}, lo que mejora recuerdo, afinidad y CTR frente a inventario abierto.</p>
      </div>
      <div class="card">
        <div class="icon">💸</div>
        <h3>Directo antes que remanente</h3>
        <p>El patrocinio directo tiene mas valor que AdSense porque controlas ubicacion, mensaje y exclusividad comercial.</p>
      </div>
    </div>
  </section>

  <section>
    <h2>Espacios disponibles</h2>
    <div class="slots">
      <div class="slot">
        <h3>Banner superior</h3>
        <p>Primera impresion bajo el hero. Ideal para awareness y campañas tacticas.</p>
        <div class="price">25 EUR / mes</div>
      </div>
      <div class="slot">
        <h3>Banner en contenido</h3>
        <p>Ubicacion premium en el punto de mayor atencion. Mejor equilibrio entre visibilidad y engagement.</p>
        <div class="price">30 EUR / mes</div>
      </div>
      <div class="slot">
        <h3>Banner pre-footer</h3>
        <p>Impacto adicional para usuarios que terminan la lectura y ya han mostrado interes real.</p>
        <div class="price">15 EUR / mes</div>
      </div>
      <div class="slot">
        <h3>Patrocinio destacado</h3>
        <p>Copy comercial adaptado al nicho, recomendacion editorial o integracion de afiliacion bajo solicitud.</p>
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
        <tr><td>Banner superior</td><td>Maxima visibilidad</td><td>25 EUR / mes</td></tr>
        <tr><td>Banner en contenido</td><td>CTR y afinidad</td><td>30 EUR / mes</td></tr>
        <tr><td>Banner pre-footer</td><td>Frecuencia extra</td><td>15 EUR / mes</td></tr>
        <tr><td>Pack presencia</td><td>Superior + contenido</td><td>45 EUR / mes</td></tr>
        <tr><td>Takeover comercial</td><td>3 espacios + exclusividad</td><td>75 EUR / mes</td></tr>
      </tbody>
    </table>
    <p style="margin-top:.75rem">Datos de trafico, screenshots de GA4, creatividades admitidas y opciones de patrocinio ampliado disponibles bajo solicitud.</p>
  </section>

  <div class="cta">
    <h2>Reservar un espacio</h2>
    <p>Escribe con tu marca, objetivo, creatividad o landing y te devolvemos propuesta, disponibilidad y opciones directas sin intermediarios.</p>
    <a class="btn" href="mailto:${CONTACT_EMAIL}?subject=Publicidad%20${domain}">Contactar por email</a>
  </div>

  <footer>
    <p>© $(date +%Y) ${name}</p>
    <p style="margin-top:.4rem"><a href="/">Inicio</a> · <a href="/privacy">Privacidad</a> · <a href="/terms">Terminos</a></p>
  </footer>
</div>
</body>
</html>
EOF
}
