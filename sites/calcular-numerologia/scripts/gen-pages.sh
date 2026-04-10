#!/usr/bin/env bash
set -euo pipefail
# Generate calcular-numerologia.es: index (calculator) + 9 number-of-life pages + nombre page

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SITE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBLIC="$SITE_DIR/public"
REPO_ROOT="$(cd "$SITE_DIR/../.." && pwd)"

source "$REPO_ROOT/shared/config.sh"

SITE_KEY="calcular-numerologia"
DOMAIN="${DOMAINS[$SITE_KEY]}"
GA4="${GA4_IDS[$SITE_KEY]}"
TODAY=$(date +%Y-%m-%d)
AD_CSS="$(ad_css)"

mkdir -p "$PUBLIC/numero-de-vida"

CROSSLINKS_HTML=$(crosslink_footer "$SITE_KEY")

# ── Common head ──────────────────────────────────────────────
gen_head() {
  local title="$1" desc="$2" canonical="$3"
  cat <<ENDHEAD
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title}</title>
  <meta name="description" content="${desc}">
  <link rel="canonical" href="https://${DOMAIN}${canonical}">
  <meta property="og:title" content="${title}">
  <meta property="og:description" content="${desc}">
  <meta property="og:type" content="website">
  <meta property="og:url" content="https://${DOMAIN}${canonical}">
  <meta property="og:locale" content="es_ES">
  <meta name="robots" content="index, follow">
  <link rel="preconnect" href="https://fonts.googleapis.com" crossorigin>
  <link href="${BRAND_FONTS}" rel="stylesheet" media="print" onload="this.media='all'">
  <noscript><link href="${BRAND_FONTS}" rel="stylesheet"></noscript>
  <script>if(location.hostname.endsWith('.web.app'))location.replace('https://${DOMAIN}'+location.pathname+location.search);</script>
  <script async src="https://www.googletagmanager.com/gtag/js?id=${GA4}"></script>
  <script>window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag('js',new Date());gtag('config','${GA4}');</script>
  <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${ADSENSE_PUB}" crossorigin="anonymous"></script>
  <link rel="preconnect" href="https://pagead2.googlesyndication.com">
  <link rel="dns-prefetch" href="https://pagead2.googlesyndication.com">
ENDHEAD
}

COMMON_CSS="
    ${CSS_VARS}
    *{margin:0;padding:0;box-sizing:border-box}
    body{font-family:'Inter',system-ui,sans-serif;background:var(--bg);color:var(--text);min-height:100vh}
    .container{max-width:820px;margin:0 auto;padding:1.5rem}
    .breadcrumb{font-size:.8rem;color:var(--muted);margin-bottom:1.5rem}
    .breadcrumb a{color:var(--accent);text-decoration:none}
    h1{font-family:'Playfair Display',serif;font-size:1.9rem;text-align:center;margin:.5rem 0}
    h1 span{background:var(--gradient);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
    h2{font-family:'Playfair Display',serif;font-size:1.15rem;color:var(--text);margin-bottom:.7rem}
    .panel{background:var(--surface);border:1px solid var(--border);border-radius:16px;padding:1.6rem;box-shadow:var(--shadow);margin-bottom:1.2rem}
    .panel p,.panel li{line-height:1.7;color:var(--muted);font-size:.9rem}
    .panel ul{padding-left:1.2rem;margin:.5rem 0}
    .cta-box{text-align:center;padding:1.8rem;background:linear-gradient(135deg,#f3eeff 0%,#fef9ee 100%);border-radius:16px;margin:1.5rem 0}
    .cta-box h3{font-family:'Playfair Display',serif;font-size:1.05rem;margin-bottom:.4rem}
    .cta-box p{color:var(--muted);font-size:.88rem;margin-bottom:.8rem}
    .cta-box a{display:inline-block;padding:.6rem 1.4rem;background:var(--accent);color:#fff;font-weight:600;border-radius:10px;text-decoration:none;font-size:.88rem;box-shadow:0 4px 14px rgba(124,58,237,.3)}
    .cta-box a:hover{background:#6d28d9;transform:translateY(-1px)}
    .network{text-align:center;font-size:.75rem;color:var(--muted);margin-top:1rem}
    .network a{color:var(--accent);text-decoration:none}
    footer{text-align:center;padding:2rem 1rem;font-size:.75rem;color:var(--muted);border-top:1px solid var(--border);margin-top:2rem}
    footer a{color:var(--accent);text-decoration:none}
${AD_CSS}
"

gen_footer() {
  cat <<ENDFOOTER
<footer>
  <p>© $(date +%Y) Calcular Numerología — Herramienta gratuita</p>
  <p><a href="/privacy">Privacidad</a> · <a href="/terms">Términos</a></p>
  $(footer_publicidad_line "$SITE_KEY")
  ${CROSSLINKS_HTML}
</footer>
ENDFOOTER
}

# ── Number data ──────────────────────────────────────────────
declare -a NUM_TITLES NUM_KEYS NUM_DESC NUM_LOVE NUM_WORK NUM_COMPAT

NUM_TITLES=("" "El Líder" "El Diplomático" "El Creativo" "El Constructor" "El Aventurero" "El Responsable" "El Buscador" "El Poderoso" "El Humanitario")
NUM_KEYS=("" "independencia, ambición, originalidad, iniciativa" "cooperación, sensibilidad, equilibrio, paz" "expresión, creatividad, comunicación, alegría" "trabajo, orden, disciplina, estabilidad" "libertad, cambio, aventura, versatilidad" "amor, hogar, responsabilidad, armonía" "introspección, espiritualidad, análisis, sabiduría" "poder, abundancia, autoridad, logro material" "compasión, idealismo, humanismo, generosidad")
NUM_DESC=("" \
"El número 1 vibra con la energía del inicio, el liderazgo y la individualidad. Las personas con número de vida 1 son pioneras natas, con una fuerte necesidad de independencia y logro personal. Son innovadoras, decididas y no temen abrir caminos nuevos. Su reto es aprender a colaborar sin perder su esencia." \
"El número 2 encarna la dualidad, la diplomacia y la sensibilidad. Quienes portan este número tienen un don natural para mediar, escuchar y crear puentes entre personas. Son empáticos, intuitivos y trabajan mejor en equipo. Su reto es evitar la dependencia emocional y valorar su propia voz." \
"El número 3 irradia creatividad, expresión y alegría de vivir. Las personas con este número de vida son comunicadoras naturales, artísticas y sociales. Tienen el don de inspirar a otros con su entusiasmo. Su reto es la dispersión y aprender a canalizar su energía creativa con enfoque." \
"El número 4 simboliza los cimientos, el trabajo duro y la estabilidad. Quienes vibran con el 4 son constructores: metódicos, fiables y con una ética de trabajo excepcional. Son los pilares de su entorno. Su reto es la rigidez y aprender que el control total es una ilusión." \
"El número 5 representa el cambio, la libertad y la experiencia. Las personas con número de vida 5 necesitan variedad, movimiento y nuevas experiencias. Son adaptables, curiosas y magnéticas. Su reto es evitar la superficialidad y comprometerse con lo que realmente importa." \
"El número 6 vibra con el amor, el hogar y la responsabilidad. Quienes tienen este número son cuidadores naturales, con un sentido profundo de la familia y la comunidad. Son armoniosos y justos. Su reto es no cargar con los problemas ajenos y aprender a poner límites sanos." \
"El número 7 es el número del buscador espiritual, el analista y el sabio. Las personas con número de vida 7 necesitan comprender el porqué de las cosas. Son introspectivas, analíticas y profundas. Su reto es no aislarse del mundo y compartir su sabiduría." \
"El número 8 encarna el poder, la abundancia y el logro material. Quienes vibran con el 8 tienen una capacidad natural para los negocios, la organización y la manifestación. Son ambiciosos y resilientes. Su reto es no confundir poder con control y usar su influencia con integridad." \
"El número 9 representa la compasión universal, el humanismo y la culminación. Las personas con este número tienen una visión amplia del mundo y un deseo profundo de contribuir. Son idealistas, generosas y sabias. Su reto es soltar el pasado y no cargar con el sufrimiento ajeno.")

NUM_LOVE=("" \
"En el amor, el 1 necesita una pareja que respete su independencia. Busca relaciones estimulantes donde pueda liderar pero también crecer. El riesgo está en querer dominar o elegir a alguien que compita constantemente." \
"El 2 en el amor es el compañero ideal: atento, romántico y dedicado. Necesita reciprocidad y armonía. El riesgo está en perderse en la relación y olvidar sus propias necesidades." \
"El 3 en el amor es alegre, cariñoso y expresivo. Necesita una pareja que disfrute socializar y compartir creatividad. El riesgo está en la superficialidad emocional y evitar conversaciones profundas." \
"El 4 en el amor es leal, estable y comprometido. Busca construir algo duradero. El riesgo está en la rutina, la falta de espontaneidad y expresar las emociones como tareas." \
"El 5 en el amor es apasionado pero necesita libertad. Las relaciones dinámicas y con espacio para crecer son ideales. El riesgo está en el miedo al compromiso y buscar siempre algo nuevo." \
"El 6 es el gran amante del zodíaco numerológico: entregado, protector y familiar. Crea hogares cálidos y relaciones profundas. El riesgo está en el sacrificio excesivo y la sobreprotección." \
"El 7 en el amor necesita conexión intelectual y espiritual. No se abre fácilmente, pero cuando lo hace, la relación es profunda. El riesgo está en el distanciamiento emocional y la reserva excesiva." \
"El 8 en el amor es generoso, protector y ambicioso. Busca una pareja igualmente fuerte. El riesgo está en priorizar el éxito material sobre la intimidad emocional." \
"El 9 en el amor es compasivo, idealista y entregado. Ama con una generosidad inmensa. El riesgo está en idealizar al otro y no ser correspondido en la misma intensidad.")

NUM_WORK=("" \
"Liderazgo, emprendimiento, innovación. Los 1 destacan como directivos, emprendedores, inventors o en cualquier rol donde la iniciativa marca la diferencia." \
"Mediación, trabajo en equipo, consejería. Los 2 brillan como diplomáticos, terapeutas, asistentes ejecutivos o en recursos humanos." \
"Arte, comunicación, entretenimiento. Los 3 destacan como escritores, actores, diseñadores, presentadores o en marketing creativo." \
"Ingeniería, finanzas, gestión de proyectos. Los 4 son excelentes arquitectos, contables, administradores o en logística." \
"Ventas, viajes, periodismo, startups. Los 5 brillan en roles dinámicos que requieren adaptabilidad y contacto con personas diferentes." \
"Educación, sanidad, hostelería, trabajo social. Los 6 destacan donde se requiere cuidado, responsabilidad y crear ambientes armoniosos." \
"Investigación, tecnología, filosofía, ciencia. Los 7 sobresalen como investigadores, programadores, escritores técnicos o en roles analíticos." \
"Dirección ejecutiva, inversión, derecho, consultoría. Los 8 son naturales en posiciones de poder, gestión financiera y estrategia empresarial." \
"ONG, arte comprometido, medicina, enseñanza. Los 9 destacan en roles con impacto social, vocación de servicio y visión global.")

NUM_COMPAT=("" "1, 3, 5" "2, 4, 8" "1, 3, 5" "2, 4, 8" "1, 3, 5" "2, 6, 9" "5, 7" "2, 4, 8" "3, 6, 9")

SITEMAP_URLS=""
PAGE_COUNT=0

# ── Generate 9 number pages ─────────────────────────────────
echo "Generating 9 number-of-life pages..."
for n in $(seq 1 9); do
  slug="numero-de-vida/${n}"
  url_path="/${slug}"
  title="Número de Vida ${n}: ${NUM_TITLES[$n]} — Significado en Numerología"
  desc="¿Tu número de vida es ${n}? Descubre el significado de ${NUM_TITLES[$n]}: ${NUM_KEYS[$n]}. Amor, trabajo y compatibilidad del número ${n}."

  prev=$(( n == 1 ? 9 : n - 1 ))
  next=$(( n == 9 ? 1 : n + 1 ))

  cat > "$PUBLIC/numero-de-vida/${n}.html" <<ENDNUM
<!DOCTYPE html>
<html lang="es">
<head>
$(gen_head "$title" "$desc" "$url_path")
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"Article","headline":"Número de Vida ${n}: ${NUM_TITLES[$n]}","description":"${desc}","author":{"@type":"Organization","name":"Calcular Numerología"},"publisher":{"@type":"Organization","name":"Calcular Numerología","url":"https://${DOMAIN}/"},"mainEntityOfPage":"https://${DOMAIN}${url_path}","inLanguage":"es"}
  </script>
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":[{"@type":"ListItem","position":1,"name":"Inicio","item":"https://${DOMAIN}/"},{"@type":"ListItem","position":2,"name":"Número de Vida","item":"https://${DOMAIN}/numero-de-vida/"},{"@type":"ListItem","position":3,"name":"Número ${n}","item":"https://${DOMAIN}${url_path}"}]}
  </script>
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"FAQPage","mainEntity":[{"@type":"Question","name":"¿Qué significa el número de vida ${n}?","acceptedAnswer":{"@type":"Answer","text":"El número ${n} (${NUM_TITLES[$n]}) representa: ${NUM_KEYS[$n]}."}},{"@type":"Question","name":"¿Con qué números es compatible el ${n}?","acceptedAnswer":{"@type":"Answer","text":"El número de vida ${n} tiene mayor compatibilidad con los números ${NUM_COMPAT[$n]}."}}]}
  </script>
  <style>
${COMMON_CSS}
    .num-hero{text-align:center;padding:2rem 0 1rem}
    .num-hero .big-num{font-family:'Playfair Display',serif;font-size:5rem;font-weight:700;background:var(--gradient);-webkit-background-clip:text;-webkit-text-fill-color:transparent;line-height:1}
    .num-hero .subtitle{color:var(--muted);font-size:.9rem;margin-top:.3rem}
    .keywords{display:flex;flex-wrap:wrap;gap:.4rem;justify-content:center;margin:1rem 0}
    .keywords .kw{padding:.25rem .7rem;border-radius:20px;font-size:.75rem;font-weight:500;background:#f3eeff;color:var(--accent);border:1px solid rgba(124,58,237,.15)}
    .compat-nums{display:flex;gap:.6rem;justify-content:center;margin:.8rem 0}
    .compat-nums a{width:2.5rem;height:2.5rem;border-radius:50%;background:var(--accent);color:#fff;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:1rem;text-decoration:none;transition:all .2s}
    .compat-nums a:hover{background:#6d28d9;transform:scale(1.1)}
    .nav-nums{display:flex;justify-content:space-between;margin:1.5rem 0}
    .nav-nums a{color:var(--accent);text-decoration:none;font-size:.85rem;font-weight:500}
  </style>
</head>
<body>
<div class="container">
  <nav class="breadcrumb"><a href="/">Calcular Numerología</a> › <a href="/numero-de-vida/">Números de Vida</a> › Número ${n}</nav>

  <div class="num-hero">
    <div class="big-num">${n}</div>
    <h1><span>${NUM_TITLES[$n]}</span></h1>
    <p class="subtitle">Número de Vida ${n}</p>
  </div>

  <div class="keywords">$(IFS=','; for kw in ${NUM_KEYS[$n]}; do echo "<span class=\"kw\">${kw## }</span>"; done)</div>

$(ad_block "🔢" "¿Vendes cursos, libros o sesiones de numerologia?" "Llega a usuarios que ya buscan respuestas personales y estan listos para profundizar." "Ver espacios y tarifas ->")

  <div class="panel">
    <h2>🔢 Significado del Número ${n}</h2>
    <p>${NUM_DESC[$n]}</p>
  </div>

  <div class="panel">
    <h2>💕 El ${n} en el Amor</h2>
    <p>${NUM_LOVE[$n]}</p>
  </div>

  <div class="panel">
    <h2>💼 El ${n} en el Trabajo</h2>
    <p>${NUM_WORK[$n]}</p>
  </div>

  <div class="panel">
    <h2>🤝 Compatibilidad del Número ${n}</h2>
    <p>Los números con mayor afinidad natural con el ${n} son:</p>
    <div class="compat-nums">$(IFS=','; for cn in ${NUM_COMPAT[$n]}; do echo "<a href=\"/numero-de-vida/${cn## }\">${cn## }</a>"; done)</div>
    <p style="margin-top:.6rem">Consulta la <a href="https://compatibilidad-signos.es/">compatibilidad de signos</a> para añadir la dimensión astrológica.</p>
  </div>

$(ad_block "✨" "Patrocina un calculo con alta intencion educativa" "Inventario ideal para escuelas holisticas, membresias premium y herramientas de autoconocimiento." "Reservar un banner premium ->")

  <div class="nav-nums">
    <a href="/numero-de-vida/${prev}">← Número ${prev}: ${NUM_TITLES[$prev]}</a>
    <a href="/numero-de-vida/">Todos</a>
    <a href="/numero-de-vida/${next}">Número ${next}: ${NUM_TITLES[$next]} →</a>
  </div>

  <div class="cta-box">
    <h3>🔮 Calcula tu número de vida</h3>
    <p>Introduce tu fecha de nacimiento y descubre tu número al instante.</p>
    <a href="/">Calcular gratis →</a>
  </div>

$(gen_footer)
</div>
</body>
</html>
ENDNUM

  SITEMAP_URLS+="  <url><loc>https://${DOMAIN}${url_path}</loc><lastmod>${TODAY}</lastmod><changefreq>monthly</changefreq><priority>0.7</priority></url>\n"
  PAGE_COUNT=$((PAGE_COUNT + 1))
done
echo "  ✓ ${PAGE_COUNT} number pages"

# ── Number index ─────────────────────────────────────────────
echo "Generating numero-de-vida index..."
NUM_GRID=""
for n in $(seq 1 9); do
  NUM_GRID+="<a class=\"num-card\" href=\"/numero-de-vida/${n}\"><span class=\"nc-num\">${n}</span><span class=\"nc-title\">${NUM_TITLES[$n]}</span><span class=\"nc-keys\">${NUM_KEYS[$n]}</span></a>"
done

cat > "$PUBLIC/numero-de-vida/index.html" <<ENDNUMIDX
<!DOCTYPE html>
<html lang="es">
<head>
$(gen_head "Los 9 Números de Vida — Significado en Numerología" "Descubre el significado de los 9 números de vida en numerología. Del 1 al 9: personalidad, amor, trabajo y compatibilidad." "/numero-de-vida/")
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":[{"@type":"ListItem","position":1,"name":"Inicio","item":"https://${DOMAIN}/"},{"@type":"ListItem","position":2,"name":"Números de Vida","item":"https://${DOMAIN}/numero-de-vida/"}]}
  </script>
  <style>
${COMMON_CSS}
    .intro{text-align:center;color:var(--muted);font-size:.92rem;line-height:1.6;max-width:620px;margin:0 auto 1.5rem}
    .num-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:1rem;margin:1.5rem 0}
    .num-card{background:var(--surface);border:1px solid var(--border);border-radius:14px;padding:1.3rem;text-align:center;text-decoration:none;color:var(--text);transition:all .2s;box-shadow:var(--shadow)}
    .num-card:hover{border-color:var(--accent);transform:translateY(-3px);box-shadow:0 8px 24px rgba(124,58,237,.15)}
    .num-card .nc-num{font-family:'Playfair Display',serif;font-size:2.5rem;font-weight:700;background:var(--gradient);-webkit-background-clip:text;-webkit-text-fill-color:transparent;display:block}
    .num-card .nc-title{font-weight:600;font-size:.9rem;display:block;margin:.3rem 0}
    .num-card .nc-keys{font-size:.72rem;color:var(--muted);line-height:1.4;display:block}
  </style>
</head>
<body>
<div class="container">
  <nav class="breadcrumb"><a href="/">Calcular Numerología</a> › Números de Vida</nav>
  <h1>Los 9 <span>Números de Vida</span></h1>
  <p class="intro">Cada número del 1 al 9 tiene una vibración única que define tu personalidad, talentos y misión de vida.</p>
  <div class="num-grid">${NUM_GRID}</div>

$(ad_block "🔢" "Publicidad premium para un publico de autoconocimiento" "Reserva una ubicacion contextual entre las fichas de numeros mas consultadas." "Informarme ->")

  <div class="cta-box">
    <h3>🔢 Calcula tu número de vida</h3>
    <p>Solo necesitas tu fecha de nacimiento.</p>
    <a href="/">Calcular gratis →</a>
  </div>

$(gen_footer)
</div>
</body>
</html>
ENDNUMIDX

SITEMAP_URLS+="  <url><loc>https://${DOMAIN}/numero-de-vida/</loc><lastmod>${TODAY}</lastmod><changefreq>monthly</changefreq><priority>0.8</priority></url>\n"
echo "  ✓ numero-de-vida/index.html"

# ══════════════════════════════════════════════════════════════
# INDEX — Interactive calculator
# ══════════════════════════════════════════════════════════════
echo "Generating index with calculator..."

cat > "$PUBLIC/index.html" <<ENDIDX
<!DOCTYPE html>
<html lang="es">
<head>
$(gen_head "Calcular Numerología Gratis — Tu Número de Vida y Nombre" "Calculadora de numerología gratis. Descubre tu número de vida a partir de tu fecha de nacimiento y el significado numerológico de tu nombre." "/")
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"WebSite","name":"Calcular Numerología","url":"https://${DOMAIN}/","description":"Calculadora de numerología gratis online.","inLanguage":"es"}
  </script>
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"FAQPage","mainEntity":[{"@type":"Question","name":"¿Cómo se calcula el número de vida?","acceptedAnswer":{"@type":"Answer","text":"Suma todos los dígitos de tu fecha de nacimiento (día + mes + año) y reduce a un solo dígito. Ejemplo: 15/03/1990 → 1+5+0+3+1+9+9+0 = 28 → 2+8 = 10 → 1+0 = 1."}},{"@type":"Question","name":"¿Qué es la numerología?","acceptedAnswer":{"@type":"Answer","text":"La numerología es un sistema milenario que estudia el significado simbólico de los números y su influencia en la vida humana. El número de vida, derivado de la fecha de nacimiento, revela rasgos de personalidad, talentos y misión."}}]}
  </script>
  <style>
${COMMON_CSS}
    .intro{text-align:center;color:var(--muted);font-size:.92rem;line-height:1.6;max-width:600px;margin:0 auto 1.5rem}
    .calc-panel{background:var(--surface);border:1px solid var(--border);border-radius:16px;padding:2rem;box-shadow:var(--shadow);margin:1.5rem 0;text-align:center}
    .calc-panel label{display:block;font-size:.8rem;font-weight:600;color:var(--muted);text-transform:uppercase;letter-spacing:.05em;margin-bottom:.3rem}
    .calc-panel input{padding:.6rem 1rem;border:1px solid var(--border);border-radius:8px;font-size:1rem;font-family:inherit;text-align:center;width:100%;max-width:300px;background:var(--bg)}
    .calc-panel input:focus{outline:none;border-color:var(--accent);box-shadow:0 0 0 3px rgba(124,58,237,.1)}
    .calc-panel .btn{margin-top:1rem;padding:.65rem 2rem;background:var(--accent);color:#fff;border:none;border-radius:10px;font-weight:600;cursor:pointer;font-size:.95rem;font-family:inherit}
    .calc-panel .btn:hover{background:#6d28d9}
    .result-box{display:none;margin:1.5rem auto;max-width:500px;text-align:center}
    .result-box.show{display:block}
    .result-box .big-num{font-family:'Playfair Display',serif;font-size:5rem;font-weight:700;background:var(--gradient);-webkit-background-clip:text;-webkit-text-fill-color:transparent;line-height:1}
    .result-box .title{font-family:'Playfair Display',serif;font-size:1.3rem;margin:.3rem 0}
    .result-box .steps{font-size:.8rem;color:var(--muted);margin:.5rem 0;font-family:monospace}
    .result-box .link{margin-top:.8rem;display:inline-block;padding:.5rem 1.2rem;background:var(--accent);color:#fff;border-radius:10px;text-decoration:none;font-weight:600;font-size:.88rem}
    .nums-preview{display:grid;grid-template-columns:repeat(auto-fill,minmax(80px,1fr));gap:.6rem;margin:1.5rem 0;max-width:500px;margin-left:auto;margin-right:auto}
    .nums-preview a{background:var(--surface);border:1px solid var(--border);border-radius:10px;padding:.8rem;text-align:center;text-decoration:none;color:var(--text);transition:all .15s}
    .nums-preview a:hover{border-color:var(--accent);transform:translateY(-2px)}
    .nums-preview a .n{font-family:'Playfair Display',serif;font-size:1.5rem;font-weight:700;color:var(--accent);display:block}
    .nums-preview a .t{font-size:.65rem;color:var(--muted)}
    .seo-text{margin:2rem 0}
    .seo-text h2{font-size:1.1rem;margin:1.2rem 0 .5rem}
    .seo-text p{line-height:1.7;color:var(--muted);font-size:.9rem;margin-bottom:.5rem}
    .seo-text ul{padding-left:1.2rem;margin:.5rem 0}
    .seo-text li{line-height:1.7;color:var(--muted);font-size:.9rem}
  </style>
</head>
<body>
<div class="container">
  <header style="text-align:center;padding:1.5rem 0 .5rem">
    <div style="font-size:.75rem;letter-spacing:.15em;text-transform:uppercase;color:var(--accent);font-weight:600">Numerología</div>
    <h1><span>Calcular Numerología</span></h1>
    <p class="intro">Introduce tu fecha de nacimiento para descubrir tu número de vida y su significado profundo. Cálculo instantáneo y gratuito.</p>
  </header>

  <div class="calc-panel">
    <label for="birthdate">Fecha de nacimiento</label>
    <input type="date" id="birthdate" max="$(date +%Y-%m-%d)">
    <br>
    <button class="btn" onclick="calculate()">Calcular mi número de vida →</button>
  </div>

$(ad_block "🔢" "Patrocina el momento de mayor atencion del usuario" "Tu mensaje aparece justo despues de la accion principal del calculo numerologico." "Ver espacios y tarifas ->")

  <div class="result-box" id="result"></div>

  <h2 style="text-align:center;margin-top:2rem">Los 9 Números de Vida</h2>
  <div class="nums-preview">
$(for n in $(seq 1 9); do echo "    <a href=\"/numero-de-vida/${n}\"><span class=\"n\">${n}</span><span class=\"t\">${NUM_TITLES[$n]}</span></a>"; done)
  </div>

$(ad_block "✨" "Publicidad directa mejor que remanente" "Mas control, mejor contexto y mas valor comercial para marcas de formacion y bienestar." "Ver media kit ->")

  <div class="cta-box">
    <h3>🌟 Complementa con tu carta astral</h3>
    <p>La numerología y la astrología juntas revelan capas más profundas de tu personalidad.</p>
    <a href="https://carta-astral-gratis.es/">Calcular carta astral gratis →</a>
  </div>

  <div class="seo-text panel">
    <h2>¿Qué es la numerología?</h2>
    <p>La numerología es un sistema ancestral que estudia la vibración y el significado simbólico de los números. Cada número del 1 al 9 posee una energía única que influye en la personalidad, las relaciones y el destino de una persona.</p>

    <h2>¿Cómo se calcula el número de vida?</h2>
    <p>El número de vida (o número de camino de vida) se obtiene sumando todos los dígitos de tu fecha de nacimiento completa y reduciendo el resultado a un solo dígito:</p>
    <ul>
      <li>Ejemplo: 15 de marzo de 1990</li>
      <li>Día: 1 + 5 = 6</li>
      <li>Mes: 0 + 3 = 3</li>
      <li>Año: 1 + 9 + 9 + 0 = 19 → 1 + 9 = 10 → 1 + 0 = 1</li>
      <li>Total: 6 + 3 + 1 = 10 → 1 + 0 = <strong>1</strong></li>
    </ul>

    <h2>¿Qué revela tu número de vida?</h2>
    <p>Tu número de vida describe tus talentos innatos, tu forma de relacionarte, tu estilo profesional y los retos que enfrentarás en tu camino. Es la base de tu perfil numerológico, complementado por otros números como el de expresión (calculado con tu nombre) y el número del alma.</p>

    <h2>Numerología y astrología</h2>
    <p>La numerología y la <a href="https://carta-astral-gratis.es/">carta astral</a> son sistemas complementarios. Mientras la astrología analiza la posición de los planetas en el momento de tu nacimiento, la numerología estudia la vibración de los números asociados. Juntas, ofrecen un retrato más completo de tu personalidad y potencial.</p>
  </div>

$(gen_footer)
</div>

<script>
const TITLES=["","El Líder","El Diplomático","El Creativo","El Constructor","El Aventurero","El Responsable","El Buscador","El Poderoso","El Humanitario"];
function reduce(n){while(n>9)n=[...String(n)].reduce((a,b)=>a+ +b,0);return n}
function calculate(){
  const d=document.getElementById('birthdate').value;
  if(!d)return;
  const digits=d.replace(/-/g,'');
  const sum=[...digits].reduce((a,b)=>a+ +b,0);
  const num=reduce(sum);
  const parts=d.split('-');
  const steps=parts[2]+'/'+parts[1]+'/'+parts[0]+' → '+[...digits].join('+')+' = '+sum+(sum>9?' → '+num:'');
  document.getElementById('result').innerHTML='<div class="big-num">'+num+'</div><div class="title">'+TITLES[num]+'</div><div class="steps">'+steps+'</div><a class="link" href="/numero-de-vida/'+num+'">Leer significado completo →</a>';
  document.getElementById('result').classList.add('show');
}
</script>
</body>
</html>
ENDIDX

SITEMAP_URLS="  <url><loc>https://${DOMAIN}/</loc><lastmod>${TODAY}</lastmod><changefreq>weekly</changefreq><priority>1.0</priority></url>\n${SITEMAP_URLS}"

# ══════════════════════════════════════════════════════════════
# STATIC FILES
# ══════════════════════════════════════════════════════════════
echo "google.com, ${ADSENSE_PUB#ca-}, DIRECT, f08c47fec0942fa0" > "$PUBLIC/ads.txt"
gen_publicidad_page "$SITE_KEY" "$PUBLIC"

cat > "$PUBLIC/robots.txt" <<ENDROBOTS
User-agent: *
Allow: /
Sitemap: https://${DOMAIN}/sitemap.xml
ENDROBOTS

SITEMAP_URLS+="  <url><loc>https://${DOMAIN}/publicidad</loc><lastmod>${TODAY}</lastmod><changefreq>monthly</changefreq><priority>0.6</priority></url>\n"

cat > "$PUBLIC/sitemap.xml" <<ENDSITEMAP
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
$(echo -e "$SITEMAP_URLS")</urlset>
ENDSITEMAP

cat > "$PUBLIC/404.html" <<END404
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Página no encontrada — Calcular Numerología</title>
  <meta name="robots" content="noindex">
  <style>${COMMON_CSS}</style>
</head>
<body>
<div class="container" style="text-align:center;padding:4rem 1rem">
  <div style="font-size:4rem">🔢</div>
  <h1>Los números no encuentran esta página</h1>
  <p style="color:var(--muted);margin:1rem 0">Vuelve al inicio para calcular tu numerología.</p>
  <a href="/" style="display:inline-block;padding:.6rem 1.5rem;background:var(--accent);color:#fff;border-radius:10px;text-decoration:none;font-weight:600">← Calcular numerología gratis</a>
</div>
</body>
</html>
END404

echo "  ✓ Static files"
echo "Done! $((PAGE_COUNT + 1)) pages + index in $PUBLIC"
