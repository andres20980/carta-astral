#!/usr/bin/env bash
set -euo pipefail
# Generate horoscopo-de-hoy.es: index + 12 sign pages with daily horoscope
# The daily content is seeded by date so it changes each day deterministically.
# In production, run this script via cron daily and re-deploy.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SITE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBLIC="$SITE_DIR/public"
REPO_ROOT="$(cd "$SITE_DIR/../.." && pwd)"

source "$REPO_ROOT/shared/config.sh"

SITE_KEY="horoscopo-de-hoy"
DOMAIN="${DOMAINS[$SITE_KEY]}"
GA4="${GA4_IDS[$SITE_KEY]}"
TODAY=$(date +%Y-%m-%d)
AD_CSS="$(ad_css)"
CLUSTER_CSS="$(cluster_css)"
TODAY_DISPLAY=$(date +"%d de %B de %Y" | sed 's/January/enero/;s/February/febrero/;s/March/marzo/;s/April/abril/;s/May/mayo/;s/June/junio/;s/July/julio/;s/August/agosto/;s/September/septiembre/;s/October/octubre/;s/November/noviembre/;s/December/diciembre/')
DOW=$(date +%u)  # 1=Mon..7=Sun

mkdir -p "$PUBLIC"

CROSSLINKS_HTML=$(crosslink_footer "$SITE_KEY")
SIGN_TITLE_TEMPLATE="Horóscopo {{name}} Hoy {{glyph}} — ${TODAY_DISPLAY}"
SIGN_DESC_TEMPLATE="Horóscopo de {{name}} para hoy ${TODAY_DISPLAY}. Predicciones de amor, trabajo y salud. Números de la suerte: {{lucky_number}}. Color del día: {{lucky_color}}."

# ── Sign data ────────────────────────────────────────────────
SLUGS=(aries tauro geminis cancer leo virgo libra escorpio sagitario capricornio acuario piscis)
declare -A NAME=([aries]="Aries" [tauro]="Tauro" [geminis]="Géminis" [cancer]="Cáncer" [leo]="Leo" [virgo]="Virgo" [libra]="Libra" [escorpio]="Escorpio" [sagitario]="Sagitario" [capricornio]="Capricornio" [acuario]="Acuario" [piscis]="Piscis")
declare -A GLYPH=([aries]="♈" [tauro]="♉" [geminis]="♊" [cancer]="♋" [leo]="♌" [virgo]="♍" [libra]="♎" [escorpio]="♏" [sagitario]="♐" [capricornio]="♑" [acuario]="♒" [piscis]="♓")
declare -A ELEMENT=([aries]="Fuego" [tauro]="Tierra" [geminis]="Aire" [cancer]="Agua" [leo]="Fuego" [virgo]="Tierra" [libra]="Aire" [escorpio]="Agua" [sagitario]="Fuego" [capricornio]="Tierra" [acuario]="Aire" [piscis]="Agua")
declare -A DATES=([aries]="21 mar – 19 abr" [tauro]="20 abr – 20 may" [geminis]="21 may – 20 jun" [cancer]="21 jun – 22 jul" [leo]="23 jul – 22 ago" [virgo]="23 ago – 22 sep" [libra]="23 sep – 22 oct" [escorpio]="23 oct – 21 nov" [sagitario]="22 nov – 21 dic" [capricornio]="22 dic – 19 ene" [acuario]="20 ene – 18 feb" [piscis]="19 feb – 20 mar")

# ── Deterministic daily content generation ───────────────────
# Uses date + sign hash to generate varying daily content
# This creates content that changes every day but is reproducible

# Aspect pools
LOVE_POOL=(
  "La Luna potencia tu sensibilidad emocional hoy. Si estás en pareja, es buen momento para conversaciones profundas. Si estás soltero/a, mantén los ojos abiertos: podrían llegar señales inesperadas."
  "Venus favorece las conexiones hoy. Las relaciones existentes se fortalecen con gestos sencillos. Si buscas amor, tu magnetismo está en su punto más alto."
  "Hoy las energías invitan a la reflexión en pareja. No es momento de grandes decisiones amorosas sino de escuchar y comprender. La paciencia será tu mejor aliada."
  "Las estrellas alinean romanticismo y pasión hoy. Exprésate sin miedo, tanto si tienes pareja como si estás conociendo a alguien nuevo. La autenticidad será irresistible."
  "Jornada de introspección emocional. Es buen día para sanar heridas pasadas y perdonar. Las relaciones que sobrevivan este análisis saldrán fortalecidas."
  "La energía de hoy favorece la armonía. Es un excelente momento para resolver tensiones y reconectar con tu pareja. Los solteros podrían sentir atracción por alguien de su entorno cercano."
  "Marte activa la pasión y la intensidad en el amor. Las relaciones viven un momento eléctrico: aprovéchalo con inteligencia emocional. Evita discusiones innecesarias."
)

WORK_POOL=(
  "Tu mente analítica está afilada hoy. Ideal para tareas que requieran concentración y resolución de problemas. Evita multitasking: el enfoque será tu superpoder."
  "Las colaboraciones fluyen bien hoy. Es buen momento para reuniones, brainstorming y proyectos en equipo. Tu capacidad de escucha impresionará a los demás."
  "Mercurio potencia tu comunicación profesional. Presentaciones, negociaciones y emails importantes tienen altas probabilidades de éxito hoy."
  "Jornada de planificación y organización. No es el mejor día para lanzar proyectos nuevos, pero sí para consolidar los que ya tienes en marcha."
  "Tu creatividad está en su punto más alto. Ideas innovadoras pueden surgir cuando menos lo esperes. Ten un cuaderno cerca y no descartes ninguna ocurrencia."
  "Hoy las estrellas favorecen decisiones financieras prudentes. Revisa tus números, ajusta presupuestos y piensa a largo plazo. Evita gastos impulsivos."
  "La energía del día impulsa la ambición. Es momento de dar ese paso que llevas posponiendo. Tu determinación están alineadas con el universo."
)

HEALTH_POOL=(
  "Prioriza el descanso hoy. Tu cuerpo necesita recuperarse y las estrellas favorecen el autocuidado. Una caminata al aire libre o una sesión de estiramientos marcarán la diferencia."
  "Tu energía vital está alta. Aprovecha para incorporar ejercicio o actividad física que lleves postergando. Tu cuerpo te lo agradecerá."
  "Las emociones pueden manifestarse como tensión física hoy. Técnicas de respiración y mindfulness serán especialmente efectivas."
  "Buen día para cuidar tu alimentación. Tu cuerpo responde bien a cambios saludables hoy. Hidrátate más de lo habitual."
  "La Luna influye en tu energía emocional y física. No te exijas demasiado pero mantén el movimiento. El equilibrio entre actividad y descanso es clave."
  "Día óptimo para hacer deporte o actividades al aire libre. Tu resistencia está en un buen momento y la actividad física mejorará tu estado de ánimo."
  "Jornada para cuidar tu salud mental. Desconecta de las pantallas cuando puedas, busca momentos de silencio y presta atención a lo que tu cuerpo te dice."
)

LUCKY_NUMS=("3, 17, 22" "5, 14, 28" "7, 11, 33" "2, 19, 26" "8, 13, 31" "1, 16, 24" "4, 20, 29" "6, 12, 27" "9, 15, 30" "1, 18, 25" "3, 21, 34" "7, 10, 23")
LUCKY_COLORS=("Rojo" "Verde" "Azul" "Dorado" "Violeta" "Naranja" "Turquesa" "Rosa" "Plateado" "Blanco" "Amarillo" "Índigo")

# Deterministic pick: hash of date+sign → index
pick_idx() {
  local seed="${TODAY}-${1}"
  local hash
  hash=$(echo -n "$seed" | cksum | cut -d' ' -f1)
  echo $(( hash % $2 ))
}

# Rating 1-5 stars deterministic
pick_rating() {
  local seed="${TODAY}-${1}-${2}"
  local hash
  hash=$(echo -n "$seed" | cksum | cut -d' ' -f1)
  echo $(( (hash % 5) + 1 ))
}

stars_html() {
  local n=$1
  local html=""
  for i in $(seq 1 5); do
    if (( i <= n )); then html+="★"; else html+="☆"; fi
  done
  echo "$html"
}

# ── Common helpers ───────────────────────────────────────────
gen_head() {
  local title="$1" desc="$2" canonical="$3" page_type="${4:-page}" content_group="${5:-content}" entity_slug="${6:-}"
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
$(canonical_host_redirect_script "$DOMAIN")
$(ga4_head_snippet "$GA4" "$SITE_KEY" "$page_type" "$content_group" "$entity_slug")
$(adsense_head_snippet)
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
    .panel p{line-height:1.7;color:var(--muted);font-size:.9rem}
    .date-badge{text-align:center;font-size:.8rem;color:var(--accent);font-weight:600;margin-bottom:1rem}
    .rating-row{display:flex;gap:1.5rem;justify-content:center;flex-wrap:wrap;margin:1rem 0}
    .rating-item{text-align:center}
    .rating-item .r-label{font-size:.72rem;text-transform:uppercase;letter-spacing:.05em;color:var(--muted);font-weight:500}
    .rating-item .r-stars{font-size:1.1rem;color:var(--gold);margin-top:.15rem}
    .lucky{display:flex;gap:1rem;justify-content:center;flex-wrap:wrap;margin:.8rem 0}
    .lucky .tag{padding:.35rem .8rem;border-radius:20px;font-size:.78rem;font-weight:500;background:var(--surface);border:1px solid var(--border)}
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
${CLUSTER_CSS}
"

gen_footer() {
  cat <<ENDFOOTER
<footer>
  <p>© $(date +%Y) Horóscopo de Hoy — Actualizado diariamente</p>
  <p><a href="/privacy">Privacidad</a> · <a href="/terms">Términos</a></p>
  $(footer_publicidad_line "$SITE_KEY")
  ${CROSSLINKS_HTML}
</footer>
ENDFOOTER
}

# ══════════════════════════════════════════════════════════════
# GENERATE 12 SIGN PAGES
# ══════════════════════════════════════════════════════════════
echo "Generating 12 daily horoscope pages..."
SITEMAP_URLS=""
INDEX_CARDS=""
PAGE_COUNT=0

for idx in "${!SLUGS[@]}"; do
  s="${SLUGS[$idx]}"
  n="${NAME[$s]}" g="${GLYPH[$s]}" e="${ELEMENT[$s]}" d="${DATES[$s]}"

  love_i=$(pick_idx "${s}-love" 7)
  work_i=$(pick_idx "${s}-work" 7)
  health_i=$(pick_idx "${s}-health" 7)

  love="${LOVE_POOL[$love_i]}"
  work="${WORK_POOL[$work_i]}"
  health="${HEALTH_POOL[$health_i]}"

  r_love=$(pick_rating "$s" "love")
  r_work=$(pick_rating "$s" "work")
  r_health=$(pick_rating "$s" "health")

  lucky_n_i=$(( ($(echo -n "${TODAY}-${s}" | cksum | cut -d' ' -f1) ) % 12 ))
  lucky_c_i=$(( ($(echo -n "${TODAY}-${s}-color" | cksum | cut -d' ' -f1) ) % 12 ))
  lucky_n="${LUCKY_NUMS[$lucky_n_i]}"
  lucky_c="${LUCKY_COLORS[$lucky_c_i]}"

  # Overall rating avg
  r_overall=$(( (r_love + r_work + r_health + 1) / 3 ))

  url_path="/${s}"
  title="${SIGN_TITLE_TEMPLATE//\{\{name\}\}/$n}"
  title="${title//\{\{glyph\}\}/$g}"
  desc="${SIGN_DESC_TEMPLATE//\{\{name\}\}/$n}"
  desc="${desc//\{\{lucky_number\}\}/$lucky_n}"
  desc="${desc//\{\{lucky_color\}\}/$lucky_c}"

  # Prev/next sign
  prev_idx=$(( (idx - 1 + 12) % 12 ))
  next_idx=$(( (idx + 1) % 12 ))
  prev_s="${SLUGS[$prev_idx]}"
  next_s="${SLUGS[$next_idx]}"

  cat > "$PUBLIC/${s}.html" <<ENDSIGN
<!DOCTYPE html>
<html lang="es">
<head>
$(gen_head "$title" "$desc" "$url_path" "daily_sign" "daily_content" "$s")
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"Article","headline":"Horóscopo ${n} Hoy","description":"${desc}","datePublished":"${TODAY}","dateModified":"${TODAY}","author":{"@type":"Organization","name":"Horóscopo de Hoy"},"publisher":{"@type":"Organization","name":"Horóscopo de Hoy","url":"https://${DOMAIN}/"},"mainEntityOfPage":"https://${DOMAIN}${url_path}","inLanguage":"es"}
  </script>
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":[{"@type":"ListItem","position":1,"name":"Inicio","item":"https://${DOMAIN}/"},{"@type":"ListItem","position":2,"name":"${n}","item":"https://${DOMAIN}${url_path}"}]}
  </script>
  <style>
${COMMON_CSS}
    .sign-hero{text-align:center;padding:1.5rem 0}
    .sign-hero .glyph{font-size:3.5rem;display:block;margin-bottom:.3rem}
    .sign-hero .dates{font-size:.8rem;color:var(--muted)}
    .nav-signs{display:flex;justify-content:space-between;margin:1.5rem 0}
    .nav-signs a{color:var(--accent);text-decoration:none;font-size:.85rem;font-weight:500}
  </style>
</head>
<body>
<div class="container">
  <nav class="breadcrumb"><a href="/">Horóscopo de Hoy</a> › ${n}</nav>

  <div class="sign-hero">
    <span class="glyph">${g}</span>
    <h1><span>Horóscopo ${n} Hoy</span></h1>
    <p class="dates">${d} · ${e}</p>
  </div>

  <div class="date-badge">📅 ${TODAY_DISPLAY}</div>

  <div class="rating-row">
    <div class="rating-item"><div class="r-label">Amor</div><div class="r-stars">$(stars_html "$r_love")</div></div>
    <div class="rating-item"><div class="r-label">Trabajo</div><div class="r-stars">$(stars_html "$r_work")</div></div>
    <div class="rating-item"><div class="r-label">Salud</div><div class="r-stars">$(stars_html "$r_health")</div></div>
  </div>

  <div class="lucky">
    <span class="tag">🔢 ${lucky_n}</span>
    <span class="tag">🎨 ${lucky_c}</span>
  </div>

$(ad_block "⭐" "¿Quieres visibilidad diaria en una audiencia recurrente?" "Aparece junto al horoscopo de amor, trabajo y salud de cada signo." "Ver espacios y tarifas ->")

  <div class="panel">
    <h2>💕 Amor</h2>
    <p>${love}</p>
  </div>

  <div class="panel">
    <h2>💼 Trabajo y Dinero</h2>
    <p>${work}</p>
  </div>

  <div class="panel">
    <h2>🏥 Salud y Bienestar</h2>
    <p>${health}</p>
  </div>

  <div class="panel">
    <h2>🌟 Consejo del día para ${n}</h2>
    <p>Hoy tu elemento ${e} $([ "$e" = "Fuego" ] && echo "te pide acción: no postergues lo importante. La energía está de tu lado, úsala con intención." || [ "$e" = "Tierra" ] && echo "te invita a confiar en el proceso. Los resultados llegan con paciencia y constancia. Mantén los pies en la tierra." || [ "$e" = "Aire" ] && echo "activa tu mente: nuevas ideas y conexiones pueden marcar la diferencia hoy. Comunica lo que sientes." || echo "amplifica tu intuición: escucha a tu cuerpo y a tus emociones. Hoy las respuestas están dentro de ti.")</p>
  </div>

  <div class="panel">
    <h2>Cómo interpretar este horóscopo de ${n}</h2>
    <p>Esta lectura diaria parte del signo solar, por eso funciona como orientación general y no como diagnóstico personal. Para aprovecharla mejor, léela junto a tu ascendente: el Sol describe identidad y energía vital, mientras el Ascendente suele mostrar cómo se manifiesta el día en decisiones, encuentros y estados de ánimo visibles.</p>
    <p>Si alguna predicción no encaja contigo, revisa qué está ocurriendo en tu carta natal completa. La Luna puede explicar cambios emocionales, Venus matiza vínculos y placer, Marte muestra cómo actúas bajo presión y Mercurio indica qué conversaciones conviene cuidar hoy.</p>
  </div>

  <div class="panel">
    <h2>Enfoque práctico para hoy</h2>
    <p>Antes de tomar una decisión importante, separa intuición de impulso. Anota una prioridad realista, una conversación pendiente y un gesto de autocuidado. Este pequeño filtro convierte el horóscopo en una herramienta práctica: no se trata de esperar que el día ocurra, sino de usar el clima simbólico para responder con más conciencia.</p>
    <p>Al final del día, revisa qué parte de la lectura tuvo sentido y cuál no. Esa comprobación evita usar el horóscopo como una predicción rígida y lo convierte en un registro personal: puedes detectar qué temas se repiten, qué tránsitos te afectan más y qué decisiones mejoran cuando las tomas con más perspectiva.</p>
    <p>Si lees también tu Luna y tu Ascendente, compara los tres mensajes. El Sol suele marcar motivación, la Luna muestra el tono emocional y el Ascendente describe cómo actúas hacia fuera. Cuando los tres coinciden, el mensaje gana fuerza; cuando se contradicen, conviene elegir una acción pequeña y flexible.</p>
    <p>Para cerrar la lectura, elige una sola acción medible: enviar un mensaje, aplazar una compra, descansar antes de responder o preparar una conversación. Esa acción pequeña es la parte realmente aprovechable del horóscopo diario.</p>
    <p>Evita tomar el texto como una orden literal. Úsalo como una lista de comprobación: qué conviene cuidar, qué puede esperar y dónde necesitas más claridad. Ese enfoque reduce decisiones impulsivas y hace que la lectura diaria tenga valor incluso cuando el día cambia de rumbo.</p>
  </div>

$(ad_block "🌙" "Patrocina un signo o el tráfico diario del sitio" "Ideal para tarot, astrología, bienestar y tiendas espirituales con repetición de impacto." "Reservar un banner destacado →")

  <div class="nav-signs">
    <a href="/${prev_s}">${GLYPH[$prev_s]} ${NAME[$prev_s]}</a>
    <a href="/">Todos los signos</a>
    <a href="/${next_s}">${NAME[$next_s]} ${GLYPH[$next_s]}</a>
  </div>

  <div class="cta-box">
    <h3>🔮 Descubre tu carta astral completa</h3>
    <p>El horóscopo diario es solo el signo solar. Tu carta natal revela mucho más.</p>
    <a href="https://carta-astral-gratis.es/">Calcular carta astral gratis →</a>
  </div>

  <div class="cta-box" style="background:linear-gradient(135deg,#eff6ff 0%,#f3eeff 100%)">
    <h3>❤️ ¿Compatible con tu signo?</h3>
    <p>Descubre la afinidad de ${n} con los otros 11 signos.</p>
    <a href="https://compatibilidad-signos.es/">Ver compatibilidad →</a>
  </div>

$(cluster_recirculation_block "$SITE_KEY")

$(gen_footer)
</div>
</body>
</html>
ENDSIGN

  SITEMAP_URLS+="  <url><loc>https://${DOMAIN}${url_path}</loc><lastmod>${TODAY}</lastmod><changefreq>daily</changefreq><priority>0.8</priority></url>\n"

  # Build index card
  INDEX_CARDS+="<a class=\"sign-card\" href=\"/${s}\"><span class=\"sc-glyph\">${g}</span><span class=\"sc-name\">${n}</span><span class=\"sc-dates\">${d}</span><span class=\"sc-stars\">$(stars_html "$r_overall")</span></a>"

  PAGE_COUNT=$((PAGE_COUNT + 1))
done
echo "  ✓ ${PAGE_COUNT} sign pages"

# ══════════════════════════════════════════════════════════════
# INDEX
# ══════════════════════════════════════════════════════════════
echo "Generating index..."

INDEX_TITLE="Horóscopo de Hoy Gratis — ${TODAY_DISPLAY}"
INDEX_DESC="Horóscopo de hoy gratis para los 12 signos del zodíaco. Predicciones diarias de amor, trabajo y salud. Actualizado el ${TODAY_DISPLAY}."

cat > "$PUBLIC/index.html" <<ENDINDEX
<!DOCTYPE html>
<html lang="es">
<head>
$(gen_head "$INDEX_TITLE" "$INDEX_DESC" "/" "tool_home" "daily_hub")
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"WebSite","name":"Horóscopo de Hoy","url":"https://${DOMAIN}/","description":"Horóscopo diario gratis para los 12 signos del zodíaco.","inLanguage":"es"}
  </script>
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"FAQPage","mainEntity":[{"@type":"Question","name":"¿Cuándo se actualiza el horóscopo?","acceptedAnswer":{"@type":"Answer","text":"El horóscopo se actualiza cada día a primera hora de la mañana, antes de las 7:00 (hora de Madrid)."}},{"@type":"Question","name":"¿Es fiable el horóscopo diario?","acceptedAnswer":{"@type":"Answer","text":"El horóscopo diario ofrece orientaciones basadas en la posición general de los astros para cada signo. Para un análisis personalizado, se recomienda calcular la carta astral completa con fecha, hora y lugar de nacimiento."}}]}
  </script>
  <style>
${COMMON_CSS}
    .intro{text-align:center;color:var(--muted);font-size:.92rem;line-height:1.6;max-width:600px;margin:0 auto 1rem}
    .signs-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:1rem;margin:1.5rem 0}
    .sign-card{background:var(--surface);border:1px solid var(--border);border-radius:14px;padding:1.3rem;text-align:center;text-decoration:none;color:var(--text);transition:all .2s;box-shadow:var(--shadow)}
    .sign-card:hover{border-color:var(--accent);transform:translateY(-3px);box-shadow:0 8px 24px rgba(124,58,237,.15)}
    .sign-card .sc-glyph{font-size:2rem;display:block;margin-bottom:.3rem}
    .sign-card .sc-name{font-family:'Playfair Display',serif;font-weight:700;font-size:.95rem;display:block}
    .sign-card .sc-dates{font-size:.7rem;color:var(--muted);display:block;margin:.2rem 0}
    .sign-card .sc-stars{font-size:.85rem;color:var(--gold);display:block}
    .seo-text{margin:2rem 0}
    .seo-text h2{font-size:1.1rem;margin:1.2rem 0 .5rem}
    .seo-text p{line-height:1.7;color:var(--muted);font-size:.9rem;margin-bottom:.5rem}
  </style>
</head>
<body>
<div class="container">
  <header style="text-align:center;padding:1.5rem 0 .5rem">
    <div style="font-size:.75rem;letter-spacing:.15em;text-transform:uppercase;color:var(--accent);font-weight:600">Astrología diaria</div>
    <h1><span>Horóscopo de Hoy</span></h1>
    <p class="intro">Predicciones diarias para los 12 signos del zodíaco. Amor, trabajo, salud y números de la suerte.</p>
    <div class="date-badge">📅 ${TODAY_DISPLAY}</div>
  </header>

  <div class="signs-grid">
${INDEX_CARDS}
  </div>

$(ad_block "⭐" "Publicidad destacada en una audiencia que vuelve cada día" "Tu marca puede mantenerse visible en un producto de consumo recurrente y muy contextual." "Informarme →")

  <div class="cta-box">
    <h3>🔮 ¿Quieres un análisis más profundo?</h3>
    <p>El horóscopo diario se basa en tu signo solar. Tu carta astral completa revela la influencia de todos los planetas.</p>
    <a href="https://carta-astral-gratis.es/">Calcular carta astral gratis →</a>
  </div>

  <div class="seo-text panel">
    <h2>¿Qué es el horóscopo del día?</h2>
    <p>El horóscopo diario analiza las influencias astrológicas generales que afectan a cada signo zodiacal durante un día concreto. Se basa en los tránsitos planetarios: el movimiento continuo de los planetas y cómo interactúan con las posiciones natales de cada signo.</p>

    <h2>¿Cómo leer tu horóscopo?</h2>
    <p>Tu signo solar (el más conocido) es un buen punto de partida, pero para una lectura más precisa, conviene también leer el horóscopo de tu signo ascendente. Si no conoces tu ascendente, puedes calcularlo en nuestra <a href="https://carta-astral-gratis.es/">herramienta de carta astral gratuita</a>.</p>

    <h2>Horóscopo y compatibilidad</h2>
    <p>Las predicciones diarias de amor pueden complementarse con un análisis de <a href="https://compatibilidad-signos.es/">compatibilidad entre signos</a> para entender mejor la dinámica de tus relaciones. También puedes explorar el <a href="https://tarot-del-dia.es/">tarot del día</a> o tu <a href="https://calcular-numerologia.es/">número de vida</a> para una visión más completa.</p>

    <h2>Por qué leer también tu ascendente</h2>
    <p>El horóscopo por signo solar resume una energía colectiva. El ascendente añade una capa más práctica porque conecta con la casa 1 de la carta natal: imagen, decisiones inmediatas y forma de responder al entorno. Si solo lees tu signo solar, tendrás una visión útil pero incompleta; si sumas ascendente y Luna, la lectura del día gana precisión.</p>
    <p>También puedes revisar la Luna cuando busques una lectura emocional. En días de tensión, cambios de humor o decisiones familiares, el signo lunar puede dar pistas más concretas que el Sol. Combinar estas tres capas permite evitar interpretaciones demasiado generales.</p>
    <p>Este enfoque no sustituye una carta natal completa, pero mejora la utilidad diaria: el Sol muestra qué te mueve, el Ascendente dónde se manifiesta y la Luna cómo lo vives por dentro. Leerlos juntos ayuda a convertir una predicción breve en una herramienta práctica.</p>
    <p>Si repites esta comparación durante varios días, podrás detectar qué signo te resulta más útil para trabajo, relaciones o estado emocional. Esa observación personal vale más que leer un único texto aislado.</p>
    <p>También ayuda revisar el horóscopo al final del día. La lectura gana valor cuando comparas el texto con hechos concretos: qué conversación se dio, qué decisión evitaste, qué energía predominó y qué patrón merece seguimiento mañana.</p>
  </div>

$(ad_block "✨" "Patrocina una ubicación de alto recuerdo" "El patrocinio directo gana valor cuando el mensaje y el contexto están alineados." "Ver espacios →")

$(cluster_recirculation_block "$SITE_KEY")

$(gen_footer)
</div>
</body>
</html>
ENDINDEX

SITEMAP_URLS="  <url><loc>https://${DOMAIN}/</loc><lastmod>${TODAY}</lastmod><changefreq>daily</changefreq><priority>1.0</priority></url>\n${SITEMAP_URLS}"

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
  <title>Página no encontrada — Horóscopo de Hoy</title>
  <meta name="robots" content="noindex">
$(canonical_host_redirect_script "$DOMAIN")
  <style>${COMMON_CSS}</style>
</head>
<body>
<div class="container" style="text-align:center;padding:4rem 1rem">
  <div style="font-size:4rem">⭐</div>
  <h1>Las estrellas no encuentran esta página</h1>
  <p style="color:var(--muted);margin:1rem 0">Vuelve al inicio para leer tu horóscopo de hoy.</p>
  <a href="/" style="display:inline-block;padding:.6rem 1.5rem;background:var(--accent);color:#fff;border-radius:10px;text-decoration:none;font-weight:600">← Horóscopo de hoy</a>
</div>
</body>
</html>
END404

echo "  ✓ Static files"
bash "$REPO_ROOT/scripts/generate-legal-pages.sh" "$SITE_KEY"
echo "Done! ${PAGE_COUNT} sign pages + index in $PUBLIC"
