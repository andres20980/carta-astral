#!/usr/bin/env bash
set -euo pipefail
# Generate 12 zodiac sign landing pages for long-tail SEO
# Each page targets "carta astral [signo]" keywords

SITE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$SITE_DIR/../.." && pwd)"
DIR="$SITE_DIR/public/signos"
source "$REPO_ROOT/shared/config.sh"
GA4="${GA4_IDS[carta-astral]}"
mkdir -p "$DIR"
SIGN_PAGE_TITLE_TEMPLATE="Carta Astral {{name}} {{glyph}} — Características, Fechas y Significado Natal"
SIGN_PAGE_DESC_TEMPLATE="Carta astral de {{name}} {{glyph}}: fechas ({{dates}}), elemento {{element}}, planeta regente {{ruler}}. Descubre cómo influye {{name}} en tu carta natal. Calcula tu carta astral gratis."

declare -A SIGNS=(
  [aries]="Aries|♈|21 de marzo – 19 de abril|Fuego|Marte|Cardinal|El primer signo del zodíaco. Aries es pura energía de inicio, impulso y coraje. Los nacidos bajo este signo son pioneros naturales, directos y apasionados. Su regente Marte les da una fuerza de voluntad imparable.|independencia, coraje, entusiasmo, determinación|impaciencia, impulsividad, tendencia a la confrontación|En la carta astral, tener el Sol, la Luna o el Ascendente en Aries indica una personalidad que necesita liderar, actuar y no quedarse quieta. Marte en Aries está domiciliado: su energía es pura y directa."
  [tauro]="Tauro|♉|20 de abril – 20 de mayo|Tierra|Venus|Fijo|El signo de la estabilidad y los sentidos. Tauro busca seguridad material y emocional, disfruta de los placeres de la vida y construye con paciencia. Su regente Venus le da un profundo sentido estético y amor por la belleza.|lealtad, paciencia, sensualidad, perseverancia|terquedad, posesividad, resistencia al cambio|Si tu carta natal tiene planetas en Tauro, esas áreas de tu vida buscarán estabilidad y placer. Venus en Tauro está domiciliado: el amor se vive de forma sensual, fiel y terrenal."
  [geminis]="Géminis|♊|21 de mayo – 20 de junio|Aire|Mercurio|Mutable|El signo de la comunicación y la curiosidad. Géminis necesita variedad, conversación y estímulo mental constante. Su regente Mercurio le da una mente ágil y versátil.|inteligencia, adaptabilidad, sociabilidad, ingenio|superficialidad, inconstancia, nerviosismo|Tener planetas en Géminis en tu carta astral señala áreas donde necesitas comunicar, aprender y moverte. Mercurio en Géminis está domiciliado: la mente es rápida, curiosa y multitarea."
  [cancer]="Cáncer|♋|21 de junio – 22 de julio|Agua|Luna|Cardinal|El signo del hogar y las emociones profundas. Cáncer nutre, protege y siente con una intensidad única. Su regente la Luna le conecta con la memoria, la familia y el instinto maternal.|empatía, intuición, protección, memoria emocional|hipersensibilidad, apego al pasado, cambios de humor|La Luna en Cáncer está domiciliada: las emociones fluyen naturalmente, la intuición es poderosa y el hogar es sagrado. Los planetas en Cáncer en tu carta natal piden cuidado y conexión emocional."
  [leo]="Leo|♌|23 de julio – 22 de agosto|Fuego|Sol|Fijo|El signo de la creatividad y el brillo personal. Leo necesita expresarse, ser reconocido y compartir su luz. Su regente el Sol le da carisma, generosidad y una presencia magnética.|creatividad, generosidad, liderazgo, calidez|orgullo, necesidad de atención, dramatismo|El Sol en Leo está domiciliado: la identidad brilla con fuerza, hay vocación artística y necesidad de ser visto. Planetas en Leo en tu carta natal piden expresión creativa y reconocimiento."
  [virgo]="Virgo|♍|23 de agosto – 22 de septiembre|Tierra|Mercurio|Mutable|El signo del análisis y el servicio. Virgo observa los detalles que nadie ve, mejora lo que toca y busca la perfección práctica. Su regente Mercurio le da una mente analítica y metódica.|precisión, servicio, análisis, humildad|perfeccionismo, autocrítica excesiva, preocupación|Mercurio en Virgo está domiciliado: la mente es práctica, detallista y orientada a soluciones. Planetas en Virgo en tu carta astral señalan áreas donde buscas orden, eficiencia y mejora continua."
  [libra]="Libra|♎|23 de septiembre – 22 de octubre|Aire|Venus|Cardinal|El signo del equilibrio y las relaciones. Libra busca la armonía, la justicia y la belleza en todo lo que le rodea. Su regente Venus le da un don natural para las relaciones y la estética.|diplomacia, equilibrio, sentido de la justicia, encanto|indecisión, dependencia de otros, evitación del conflicto|Venus en Libra está domiciliado: el amor se vive buscando un igual, la belleza y la armonía son esenciales. Planetas en Libra en tu carta natal piden equilibrio, colaboración y justicia."
  [escorpio]="Escorpio|♏|23 de octubre – 21 de noviembre|Agua|Plutón (co-regente Marte)|Fijo|El signo de la transformación y la profundidad. Escorpio ve bajo la superficie, investiga lo oculto y no teme la intensidad emocional. Su regente Plutón le da poder regenerativo.|intensidad, lealtad profunda, intuición, capacidad de transformación|celos, tendencia al control, resentimiento|Plutón en Escorpio intensifica la generación nacida con este tránsito. Planetas en Escorpio en tu carta astral señalan áreas donde vives crisis, renacimientos y experiencias transformadoras."
  [sagitario]="Sagitario|♐|22 de noviembre – 21 de diciembre|Fuego|Júpiter|Mutable|El signo de la expansión y la búsqueda de sentido. Sagitario necesita viajar, aprender y conectar con una verdad más grande. Su regente Júpiter le da optimismo, suerte y visión amplia.|optimismo, honestidad, aventura, generosidad|falta de tacto, exceso de confianza, inconstancia|Júpiter en Sagitario está domiciliado: la fe, los viajes y la filosofía de vida fluyen naturalmente. Planetas en Sagitario en tu carta astral piden libertad, significado y horizontes amplios."
  [capricornio]="Capricornio|♑|22 de diciembre – 19 de enero|Tierra|Saturno|Cardinal|El signo de la ambición y la estructura. Capricornio construye a largo plazo, respeta la tradición y alcanza sus metas con disciplina. Su regente Saturno le da madurez, responsabilidad y resistencia.|disciplina, responsabilidad, ambición, madurez|rigidez, frialdad aparente, exceso de autoexigencia|Saturno en Capricornio está domiciliado: la estructura, el deber y la carrera profesional son pilares de vida. Planetas en Capricornio en tu carta natal piden esfuerzo sostenido, logros reales y respeto."
  [acuario]="Acuario|♒|20 de enero – 18 de febrero|Aire|Urano (co-regente Saturno)|Fijo|El signo de la innovación y la comunidad. Acuario piensa en el futuro, rompe esquemas y valora la libertad individual dentro del colectivo. Su regente Urano le da originalidad y visión de progreso.|originalidad, humanitarismo, independencia, visión|distanciamiento emocional, excentricidad, rebeldía por sistema|Urano en Acuario está domiciliado: la revolución, la tecnología y los ideales sociales son motores de vida. Planetas en Acuario en tu carta astral piden innovación, libertad y conexión con causas más grandes."
  [piscis]="Piscis|♓|19 de febrero – 20 de marzo|Agua|Neptuno (co-regente Júpiter)|Mutable|El último signo del zodíaco, donde todo se disuelve y se fusiona. Piscis es pura empatía, imaginación y espiritualidad. Su regente Neptuno le da conexión con lo invisible, lo artístico y lo trascendente.|empatía, creatividad, espiritualidad, compasión|evasión, confusión de límites, idealismo excesivo|Neptuno en Piscis está domiciliado: la espiritualidad, el arte y la compasión universal son experiencias profundas. Planetas en Piscis en tu carta natal señalan áreas donde disuelves fronteras y conectas con algo más allá de lo material."
)

for slug in aries tauro geminis cancer leo virgo libra escorpio sagitario capricornio acuario piscis; do
  IFS='|' read -r name glyph dates element ruler modality desc strengths weaknesses chart_meaning <<< "${SIGNS[$slug]}"
  page_title="${SIGN_PAGE_TITLE_TEMPLATE//\{\{name\}\}/$name}"
  page_title="${page_title//\{\{glyph\}\}/$glyph}"
  page_desc="${SIGN_PAGE_DESC_TEMPLATE//\{\{name\}\}/$name}"
  page_desc="${page_desc//\{\{glyph\}\}/$glyph}"
  page_desc="${page_desc//\{\{dates\}\}/$dates}"
  page_desc="${page_desc//\{\{element\}\}/$element}"
  page_desc="${page_desc//\{\{ruler\}\}/$ruler}"
  cat > "$DIR/$slug.html" <<HEREDOC
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${page_title}</title>
  <link rel="icon" type="image/svg+xml" href="/favicon.svg">
  <meta name="description" content="${page_desc}">
  <meta name="keywords" content="carta astral ${slug}, ${slug} carta natal, ${slug} caracteristicas, signo ${slug}, ascendente ${slug}, ${slug} planeta regente, carta astral gratis ${slug}">
  <link rel="canonical" href="https://carta-astral-gratis.es/signos/${slug}">
  <meta property="og:title" content="Carta Astral ${name} ${glyph} — Significado en tu carta natal">
  <meta property="og:description" content="${name}: ${dates}. Elemento ${element}, regente ${ruler}. Descubre qué significa ${name} en tu mapa astral.">
  <meta property="og:type" content="article">
  <meta property="og:url" content="https://carta-astral-gratis.es/signos/${slug}">
  <meta property="og:locale" content="es_ES">
  <meta name="robots" content="index, follow">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;700&family=Inter:wght@300;400;500;600&display=swap" rel="stylesheet">
  <!-- GA4 -->
$(ga4_head_snippet "$GA4" "carta-astral" "sign_profile" "evergreen" "$slug")
  <!-- AdSense -->
  <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${ADSENSE_PUB}" crossorigin="anonymous"></script>
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"Article","headline":"Carta Astral ${name} ${glyph}","description":"${name} en la carta astral: significado, fechas, elemento y cómo influye en tu mapa natal.","author":{"@type":"Organization","name":"Carta Astral Gratis"},"publisher":{"@type":"Organization","name":"Carta Astral Gratis","url":"https://carta-astral-gratis.es/"},"mainEntityOfPage":"https://carta-astral-gratis.es/signos/${slug}","inLanguage":"es"}
  </script>
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":[{"@type":"ListItem","position":1,"name":"Inicio","item":"https://carta-astral-gratis.es/"},{"@type":"ListItem","position":2,"name":"Signos","item":"https://carta-astral-gratis.es/signos/"},{"@type":"ListItem","position":3,"name":"${name}","item":"https://carta-astral-gratis.es/signos/${slug}"}]}
  </script>
  <style>
    :root{--bg:#faf8f5;--surface:#fff;--border:#e8e0d8;--text:#2d2a26;--muted:#7a7268;--accent:#7c3aed;--accent2:#c084fc;--gold:#d4a017;--gradient:linear-gradient(135deg,#7c3aed 0%,#c084fc 50%,#d4a017 100%);--shadow:0 2px 12px rgba(124,58,237,.08)}
    *{margin:0;padding:0;box-sizing:border-box}
    body{font-family:'Inter',system-ui,sans-serif;background:var(--bg);color:var(--text);min-height:100vh}
    .container{max-width:780px;margin:0 auto;padding:1.5rem}
    .breadcrumb{font-size:.8rem;color:var(--muted);margin-bottom:1.5rem}
    .breadcrumb a{color:var(--accent);text-decoration:none}
    .hero-sign{text-align:center;padding:2rem 0}
    .hero-sign .glyph{font-size:4rem;display:block;margin-bottom:.5rem}
    .hero-sign h1{font-family:'Playfair Display',serif;font-size:2rem;margin-bottom:.3rem}
    .hero-sign h1 span{background:var(--gradient);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
    .hero-sign .dates{color:var(--muted);font-size:.9rem}
    .panel{background:var(--surface);border:1px solid var(--border);border-radius:16px;padding:1.8rem;box-shadow:var(--shadow);margin-bottom:1.2rem}
    .panel h2{font-family:'Playfair Display',serif;font-size:1.2rem;color:var(--text);margin-bottom:.8rem}
    .panel p,.panel li{line-height:1.7;color:var(--muted);font-size:.9rem}
    .panel ul{padding-left:1.2rem;margin:.5rem 0}
    .meta-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:.8rem;margin-bottom:1.5rem}
    .meta-card{background:var(--bg);border:1px solid var(--border);border-radius:10px;padding:.8rem;text-align:center}
    .meta-card .label{font-size:.7rem;text-transform:uppercase;letter-spacing:.05em;color:var(--muted);font-weight:500}
    .meta-card .value{font-weight:600;font-size:.95rem;color:var(--text);margin-top:.2rem}
    .cta-box{text-align:center;padding:2rem;background:linear-gradient(135deg,#f3eeff 0%,#fef9ee 100%);border-radius:16px;margin:1.5rem 0}
    .cta-box h3{font-family:'Playfair Display',serif;font-size:1.1rem;margin-bottom:.5rem}
    .cta-box p{color:var(--muted);font-size:.9rem;margin-bottom:1rem}
    .cta-box a{display:inline-block;padding:.65rem 1.5rem;background:var(--accent);color:#fff;font-weight:600;border-radius:10px;text-decoration:none;font-size:.9rem;box-shadow:0 4px 14px rgba(124,58,237,.3);transition:all .2s}
    .cta-box a:hover{background:#6d28d9;transform:translateY(-1px)}
    footer{text-align:center;padding:2rem 1rem;font-size:.75rem;color:var(--muted);border-top:1px solid var(--border);margin-top:2rem}
    footer a{color:var(--accent);text-decoration:none}
  </style>
</head>
<body>
<div class="container">
  <nav class="breadcrumb"><a href="/">Carta Astral Gratis</a> › <a href="/signos/">Signos</a> › ${name}</nav>

  <div class="hero-sign">
    <span class="glyph">${glyph}</span>
    <h1><span>${name}</span> en la Carta Astral</h1>
    <p class="dates">${dates}</p>
  </div>

  <div class="meta-grid">
    <div class="meta-card"><div class="label">Elemento</div><div class="value">${element}</div></div>
    <div class="meta-card"><div class="label">Regente</div><div class="value">${ruler}</div></div>
    <div class="meta-card"><div class="label">Modalidad</div><div class="value">${modality}</div></div>
    <div class="meta-card"><div class="label">Fechas</div><div class="value">${dates}</div></div>
  </div>

  <div class="panel">
    <h2>${glyph} ¿Qué es ${name}?</h2>
    <p>${desc}</p>
  </div>

  <div class="panel">
    <h2>Fortalezas de ${name}</h2>
    <ul>
$(IFS=','; for s in $strengths; do echo "      <li>${s## }</li>"; done)
    </ul>
  </div>

  <div class="panel">
    <h2>Desafíos de ${name}</h2>
    <ul>
$(IFS=','; for w in $weaknesses; do echo "      <li>${w## }</li>"; done)
    </ul>
  </div>

  <div class="panel">
    <h2>${name} en tu Carta Natal</h2>
    <p>${chart_meaning}</p>
  </div>

  <div class="cta-box">
    <h3>✨ Calcula tu Carta Astral Gratis</h3>
    <p>Descubre dónde tienes a ${name} en tu mapa natal — qué casas y planetas activa en tu vida.</p>
    <a href="/">Calcular mi carta astral →</a>
  </div>
</div>

<footer>
  <p>© 2026 Carta Astral Gratis · Cálculo con Swiss Ephemeris · Sistema Placidus</p>
  <p style="margin-top:.3rem"><a href="/privacy">Privacidad</a> · <a href="/terms">Términos</a> · <a href="/">Inicio</a></p>
  <p style="margin-top:.5rem;font-size:.85rem">🔮 <a href="https://compatibilidad-signos.es" target="_blank" rel="noopener">Compatibilidad</a> · <a href="https://tarot-del-dia.es" target="_blank" rel="noopener">Tarot</a> · <a href="https://calcular-numerologia.es" target="_blank" rel="noopener">Numerología</a> · <a href="https://horoscopo-de-hoy.es" target="_blank" rel="noopener">Horóscopo</a></p>
</footer>
</body>
</html>
HEREDOC
  echo "✅ Generated $DIR/$slug.html"
done

# Generate index page for /signos/
cat > "$DIR/index.html" <<HEREDOC
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Los 12 Signos del Zodíaco — Carta Astral Gratis</title>
  <link rel="icon" type="image/svg+xml" href="/favicon.svg">
  <meta name="description" content="Los 12 signos del zodíaco: características, fechas, elementos y significado en la carta astral. Aries, Tauro, Géminis, Cáncer, Leo, Virgo, Libra, Escorpio, Sagitario, Capricornio, Acuario y Piscis.">
  <link rel="canonical" href="https://carta-astral-gratis.es/signos/">
  <meta name="robots" content="index, follow">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;700&family=Inter:wght@300;400;500;600&display=swap" rel="stylesheet">
$(ga4_head_snippet "$GA4" "carta-astral" "content_hub" "hub" "signos")
  <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${ADSENSE_PUB}" crossorigin="anonymous"></script>
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":[{"@type":"ListItem","position":1,"name":"Inicio","item":"https://carta-astral-gratis.es/"},{"@type":"ListItem","position":2,"name":"Signos del Zodíaco","item":"https://carta-astral-gratis.es/signos/"}]}
  </script>
  <style>
    :root{--bg:#faf8f5;--surface:#fff;--border:#e8e0d8;--text:#2d2a26;--muted:#7a7268;--accent:#7c3aed;--accent2:#c084fc;--gold:#d4a017;--gradient:linear-gradient(135deg,#7c3aed 0%,#c084fc 50%,#d4a017 100%);--shadow:0 2px 12px rgba(124,58,237,.08)}
    *{margin:0;padding:0;box-sizing:border-box}
    body{font-family:'Inter',system-ui,sans-serif;background:var(--bg);color:var(--text);min-height:100vh}
    .container{max-width:780px;margin:0 auto;padding:1.5rem}
    .breadcrumb{font-size:.8rem;color:var(--muted);margin-bottom:1.5rem}
    .breadcrumb a{color:var(--accent);text-decoration:none}
    h1{font-family:'Playfair Display',serif;font-size:2rem;text-align:center;margin:1.5rem 0}
    h1 span{background:var(--gradient);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
    .intro{text-align:center;color:var(--muted);font-size:.95rem;line-height:1.6;max-width:600px;margin:0 auto 2rem}
    .signs-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(170px,1fr));gap:1rem}
    .sign-card{background:var(--surface);border:1px solid var(--border);border-radius:14px;padding:1.5rem;text-align:center;text-decoration:none;color:var(--text);transition:all .2s;box-shadow:var(--shadow)}
    .sign-card:hover{border-color:var(--accent);transform:translateY(-3px);box-shadow:0 8px 24px rgba(124,58,237,.15)}
    .sign-card .glyph{font-size:2.2rem;display:block;margin-bottom:.5rem}
    .sign-card .name{font-family:'Playfair Display',serif;font-weight:700;font-size:1rem}
    .sign-card .dates{font-size:.72rem;color:var(--muted);margin-top:.3rem}
    .sign-card .element{font-size:.65rem;text-transform:uppercase;letter-spacing:.06em;font-weight:600;margin-top:.4rem;padding:2px 8px;border-radius:10px;display:inline-block}
    .el-fuego{color:#ef4444;background:#fef2f2}.el-tierra{color:#16a34a;background:#f0fdf4}
    .el-aire{color:#7c3aed;background:#f3eeff}.el-agua{color:#3b82f6;background:#eff6ff}
    footer{text-align:center;padding:2rem 1rem;font-size:.75rem;color:var(--muted);border-top:1px solid var(--border);margin-top:2rem}
    footer a{color:var(--accent);text-decoration:none}
  </style>
</head>
<body>
<div class="container">
  <nav class="breadcrumb"><a href="/">Carta Astral Gratis</a> › Signos del Zodíaco</nav>
  <h1>Los 12 <span>Signos del Zodíaco</span></h1>
  <p class="intro">Cada signo representa una energía arquetipal. Descubre las características de cada uno y cómo influyen en tu carta astral natal.</p>
  <div class="signs-grid">
    <a class="sign-card" href="/signos/aries"><span class="glyph">♈</span><span class="name">Aries</span><span class="dates">21 mar – 19 abr</span><span class="element el-fuego">Fuego</span></a>
    <a class="sign-card" href="/signos/tauro"><span class="glyph">♉</span><span class="name">Tauro</span><span class="dates">20 abr – 20 may</span><span class="element el-tierra">Tierra</span></a>
    <a class="sign-card" href="/signos/geminis"><span class="glyph">♊</span><span class="name">Géminis</span><span class="dates">21 may – 20 jun</span><span class="element el-aire">Aire</span></a>
    <a class="sign-card" href="/signos/cancer"><span class="glyph">♋</span><span class="name">Cáncer</span><span class="dates">21 jun – 22 jul</span><span class="element el-agua">Agua</span></a>
    <a class="sign-card" href="/signos/leo"><span class="glyph">♌</span><span class="name">Leo</span><span class="dates">23 jul – 22 ago</span><span class="element el-fuego">Fuego</span></a>
    <a class="sign-card" href="/signos/virgo"><span class="glyph">♍</span><span class="name">Virgo</span><span class="dates">23 ago – 22 sep</span><span class="element el-tierra">Tierra</span></a>
    <a class="sign-card" href="/signos/libra"><span class="glyph">♎</span><span class="name">Libra</span><span class="dates">23 sep – 22 oct</span><span class="element el-aire">Aire</span></a>
    <a class="sign-card" href="/signos/escorpio"><span class="glyph">♏</span><span class="name">Escorpio</span><span class="dates">23 oct – 21 nov</span><span class="element el-agua">Agua</span></a>
    <a class="sign-card" href="/signos/sagitario"><span class="glyph">♐</span><span class="name">Sagitario</span><span class="dates">22 nov – 21 dic</span><span class="element el-fuego">Fuego</span></a>
    <a class="sign-card" href="/signos/capricornio"><span class="glyph">♑</span><span class="name">Capricornio</span><span class="dates">22 dic – 19 ene</span><span class="element el-tierra">Tierra</span></a>
    <a class="sign-card" href="/signos/acuario"><span class="glyph">♒</span><span class="name">Acuario</span><span class="dates">20 ene – 18 feb</span><span class="element el-aire">Aire</span></a>
    <a class="sign-card" href="/signos/piscis"><span class="glyph">♓</span><span class="name">Piscis</span><span class="dates">19 feb – 20 mar</span><span class="element el-agua">Agua</span></a>
  </div>
</div>
<footer>
  <p>© 2026 Carta Astral Gratis · Cálculo con Swiss Ephemeris · Sistema Placidus</p>
  <p style="margin-top:.3rem"><a href="/privacy">Privacidad</a> · <a href="/terms">Términos</a> · <a href="/">Calcular carta astral</a></p>
  <p style="margin-top:.5rem;font-size:.85rem">🔮 <a href="https://compatibilidad-signos.es" target="_blank" rel="noopener">Compatibilidad</a> · <a href="https://tarot-del-dia.es" target="_blank" rel="noopener">Tarot</a> · <a href="https://calcular-numerologia.es" target="_blank" rel="noopener">Numerología</a> · <a href="https://horoscopo-de-hoy.es" target="_blank" rel="noopener">Horóscopo</a></p>
</footer>
</body>
</html>
HEREDOC
echo "✅ Generated $DIR/index.html"
echo "🎉 All 13 pages generated!"
