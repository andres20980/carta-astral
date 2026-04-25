#!/usr/bin/env bash
set -euo pipefail
# Generate tarot-del-dia.es: index (interactive spread) + 22 major arcana pages + 56 minor arcana pages

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SITE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBLIC="$SITE_DIR/public"
REPO_ROOT="$(cd "$SITE_DIR/../.." && pwd)"

source "$REPO_ROOT/shared/config.sh"

SITE_KEY="tarot-del-dia"
DOMAIN="${DOMAINS[$SITE_KEY]}"
GA4="${GA4_IDS[$SITE_KEY]}"
TODAY=$(date +%Y-%m-%d)
AD_CSS="$(ad_css)"
CLUSTER_CSS="$(cluster_css)"

mkdir -p "$PUBLIC/arcanos-mayores" "$PUBLIC/arcanos-menores"

CROSSLINKS_HTML=$(crosslink_footer "$SITE_KEY")

# ── Common head ──────────────────────────────────────────────
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
${CLUSTER_CSS}
"

gen_footer() {
  cat <<ENDFOOTER
<footer>
  <p>© $(date +%Y) Tarot del Día — Herramienta gratuita de tarot</p>
  <p><a href="/privacy">Privacidad</a> · <a href="/terms">Términos</a></p>
  $(footer_publicidad_line "$SITE_KEY")
  ${CROSSLINKS_HTML}
</footer>
ENDFOOTER
}

# ══════════════════════════════════════════════════════════════
# MAJOR ARCANA DATA (22 cards)
# ══════════════════════════════════════════════════════════════
declare -a MAJOR_SLUGS MAJOR_NAMES MAJOR_NUMS MAJOR_KEYS MAJOR_UPRIGHT MAJOR_REVERSED MAJOR_DESC

MAJOR_SLUGS=(el-loco el-mago la-sacerdotisa la-emperatriz el-emperador el-sumo-sacerdote los-enamorados el-carro la-fuerza el-ermitano la-rueda-de-la-fortuna la-justicia el-colgado la-muerte la-templanza el-diablo la-torre la-estrella la-luna el-sol el-juicio el-mundo)
MAJOR_NAMES=("El Loco" "El Mago" "La Sacerdotisa" "La Emperatriz" "El Emperador" "El Sumo Sacerdote" "Los Enamorados" "El Carro" "La Fuerza" "El Ermitaño" "La Rueda de la Fortuna" "La Justicia" "El Colgado" "La Muerte" "La Templanza" "El Diablo" "La Torre" "La Estrella" "La Luna" "El Sol" "El Juicio" "El Mundo")
MAJOR_NUMS=("0" "I" "II" "III" "IV" "V" "VI" "VII" "VIII" "IX" "X" "XI" "XII" "XIII" "XIV" "XV" "XVI" "XVII" "XVIII" "XIX" "XX" "XXI")
MAJOR_KEYS=("libertad, espontaneidad, nuevos comienzos" "manifestación, poder, creatividad" "intuición, misterio, sabiduría interior" "abundancia, fertilidad, creatividad" "autoridad, estructura, estabilidad" "tradición, fe, conformidad" "amor, elección, unión" "determinación, victoria, voluntad" "coraje, paciencia, dominio interior" "introspección, búsqueda, soledad" "destino, ciclos, cambio inevitable" "equilibrio, verdad, causa y efecto" "sacrificio, nueva perspectiva, rendición" "transformación, fin de un ciclo, renacimiento" "equilibrio, moderación, paciencia" "atadura, materialismo, sombra" "destrucción repentina, revelación, liberación" "esperanza, inspiración, serenidad" "ilusión, miedo, subconsciente" "alegría, éxito, vitalidad" "renovación, despertar, evaluación" "completitud, logro, integración")
MAJOR_UPRIGHT=("aventura, libertad, inocencia" "habilidad, concentración, recursos" "intuición, silencio, conocimiento oculto" "naturaleza, nutrición, abundancia" "control, liderazgo, disciplina" "enseñanza, guía espiritual, tradición" "relaciones, armonía, elecciones importantes" "ambición, triunfo, autocontrol" "valor interior, compasión, resistencia" "sabiduría, retiro, guía interior" "oportunidad, karma, destino" "honestidad, ley, imparcialidad" "pausa, entrega, iluminación" "cambio profundo, transición, soltar" "armonía, salud, propósito" "esclavitud, adicción, exceso" "cambio abrupto, crisis, verdad oculta" "fe, calma, conexión cósmica" "ansiedad, confusión, engaño" "felicidad, éxito, optimismo" "juicio, redención, llamada interior" "realización, viaje completo, celebración")
MAJOR_REVERSED=("imprudencia, riesgo innecesario, caos" "engaño, manipulación, talentos desperdiciados" "secretos, desconexión, silencio excesivo" "dependencia, bloqueo creativo, abandono" "tiranía, rigidez, abuso de poder" "dogmatismo, rebeldía, restricción" "desequilibrio, desalineación, indecisión" "agresividad, falta de dirección, derrota" "debilidad, inseguridad, falta de disciplina" "aislamiento, paranoia, reclusión" "mala suerte, resistencia al cambio, estancamiento" "injusticia, deshonestidad, falta de responsabilidad" "retraso, resistencia, indecisión" "miedo al cambio, estancamiento, decadencia" "desequilibrio, exceso, falta de visión" "liberación, independencia, enfrentar miedos" "resistencia al cambio, repetir errores, dolor evitable" "desesperanza, pesimismo, desconexión" "claridad, superación de miedos, comprensión" "tristeza, pesimismo, falta de éxito temporal" "autocrítica excesiva, duda, miedo al cambio" "incompleto, atajos, falta de cierre")
MAJOR_DESC=("El Loco representa el espíritu libre que da el salto al vacío con confianza. Es el inicio del viaje, la inocencia ante lo desconocido y la valentía de empezar sin garantías. Conecta con la energía de Urano y el elemento Aire." "El Mago canaliza los cuatro elementos hacia la manifestación concreta. Tiene todos los recursos a su disposición y el poder de transformar ideas en realidad. Conecta con Mercurio y la comunicación creativa." "La Sacerdotisa guarda los misterios del subconsciente. Invita a mirar hacia dentro, a confiar en la intuición y a escuchar lo que no se dice con palabras. Conecta con la Luna y el elemento Agua." "La Emperatriz encarna la Madre Tierra: creatividad, sensualidad y abundancia natural. Todo lo que toca florece. Conecta con Venus y la fertilidad de la naturaleza." "El Emperador construye imperios con disciplina y visión a largo plazo. Representa la estructura, el orden y la autoridad responsable. Conecta con Aries y Marte." "El Sumo Sacerdote transmite la sabiduría ancestral y las tradiciones. Es el puente entre lo terrenal y lo espiritual, el maestro que guía con experiencia. Conecta con Tauro y Venus." "Los Enamorados presentan una encrucijada fundamental: elegir con el corazón alineado con la mente. Representan la unión, el amor verdadero y las decisiones que definen el camino. Conecta con Géminis y Mercurio." "El Carro avanza con determinación imparable. La voluntad domina a las emociones y la meta está clara. Conecta con Cáncer y la protección emocional canalizada en acción." "La Fuerza no es la del músculo sino la del espíritu. Paciencia, compasión y dominio de los instintos. Es el león domesticado por el amor. Conecta con Leo y el corazón." "El Ermitaño se retira del ruido para encontrar su verdad interior. La soledad elegida es su herramienta de sabiduría. Conecta con Virgo y Mercurio en su faceta más analítica." "La Rueda de la Fortuna gira sin cesar: lo que sube baja y lo que baja vuelve a subir. Recuerda que todo es cíclico y que el cambio es la única constante. Conecta con Júpiter y la expansión." "La Justicia pesa cada acción con precisión. Lo que siembras cosechas, sin excepciones. Invita a la honestidad radical y a asumir consecuencias. Conecta con Libra y Venus." "El Colgado ve el mundo desde un ángulo diferente. Al rendirse, gana una perspectiva que no tenía. El sacrificio voluntario puede ser la mayor liberación. Conecta con Neptuno y el Agua." "La Muerte no es un final sino una metamorfosis profunda. Lo viejo debe morir para que nazca lo nuevo. Es la transformación más poderosa del tarot. Conecta con Escorpio y Plutón." "La Templanza mezcla opuestos con maestría alquímica. Paciencia, moderación y fe en el proceso. Todo llega a su tiempo justo. Conecta con Sagitario y Júpiter." "El Diablo refleja nuestras cadenas autoimpuestas: adicciones, miedos, apegos materiales. Reconocer la sombra es el primer paso para liberarse. Conecta con Capricornio y Saturno." "La Torre destruye en un instante lo que estaba construido sobre cimientos falsos. Aunque dolorosa, la revelación libera. Conecta con Marte y la energía de ruptura." "La Estrella brilla después de la tormenta. Es la esperanza serena, la fe renovada y la conexión con el universo. Conecta con Acuario y Urano en su faceta más luminosa." "La Luna ilumina el mundo de los sueños, las sombras y los miedos inconscientes. Nada es lo que parece bajo su luz. Invita a explorar el subconsciente con valentía. Conecta con Piscis y Neptuno." "El Sol irradia alegría pura, éxito y vitalidad. Es la carta más positiva del tarot: claridad, confianza y energía vital al máximo. Conecta con el Sol y Leo." "El Juicio llama al despertar final. Es hora de evaluar el camino recorrido, perdonar y responder a una vocación más alta. Conecta con Plutón y la renovación total." "El Mundo es la culminación del viaje. Todo se integra, se completa y se celebra. Es el logro máximo antes de que un nuevo ciclo comience. Conecta con Saturno y la maestría.")

SITEMAP_URLS=""
PAGE_COUNT=0
MAJOR_TITLE_TEMPLATE="{{name}} ({{num}}) — Significado en el Tarot | Tarot del Día"
MAJOR_DESC_TEMPLATE="Significado de {{name}} (Arcano Mayor {{num}}) en el tarot. Al derecho: {{upright}}. Invertida: {{reversed}}. Descubre su mensaje para hoy."

# ── Generate Major Arcana pages ──────────────────────────────
echo "Generating 22 major arcana pages..."
for i in "${!MAJOR_SLUGS[@]}"; do
  slug="${MAJOR_SLUGS[$i]}"
  name="${MAJOR_NAMES[$i]}"
  num="${MAJOR_NUMS[$i]}"
  keys="${MAJOR_KEYS[$i]}"
  upright="${MAJOR_UPRIGHT[$i]}"
  reversed="${MAJOR_REVERSED[$i]}"
  desc="${MAJOR_DESC[$i]}"

  url_path="/arcanos-mayores/${slug}"
  title="${MAJOR_TITLE_TEMPLATE//\{\{name\}\}/$name}"
  title="${title//\{\{num\}\}/$num}"

  meta_desc="${MAJOR_DESC_TEMPLATE//\{\{name\}\}/$name}"
  meta_desc="${meta_desc//\{\{num\}\}/$num}"
  meta_desc="${meta_desc//\{\{upright\}\}/$upright}"
  meta_desc="${meta_desc//\{\{reversed\}\}/$reversed}"

  # Prev/next navigation
  prev_idx=$(( (i - 1 + 22) % 22 ))
  next_idx=$(( (i + 1) % 22 ))

  cat > "$PUBLIC/arcanos-mayores/${slug}.html" <<ENDCARD
<!DOCTYPE html>
<html lang="es">
<head>
$(gen_head "$title" "$meta_desc" "$url_path" "arcana_profile" "evergreen" "$slug")
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"Article","headline":"${name} — Significado en el Tarot","description":"${meta_desc}","author":{"@type":"Organization","name":"Tarot del Día"},"publisher":{"@type":"Organization","name":"Tarot del Día","url":"https://${DOMAIN}/"},"mainEntityOfPage":"https://${DOMAIN}${url_path}","inLanguage":"es"}
  </script>
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":[{"@type":"ListItem","position":1,"name":"Inicio","item":"https://${DOMAIN}/"},{"@type":"ListItem","position":2,"name":"Arcanos Mayores","item":"https://${DOMAIN}/arcanos-mayores"},{"@type":"ListItem","position":3,"name":"${name}","item":"https://${DOMAIN}${url_path}"}]}
  </script>
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"FAQPage","mainEntity":[{"@type":"Question","name":"¿Qué significa ${name} en el tarot?","acceptedAnswer":{"@type":"Answer","text":"${name} (Arcano ${num}) representa: ${keys}. Al derecho indica ${upright}. Invertida señala ${reversed}."}},{"@type":"Question","name":"¿${name} es una carta positiva o negativa?","acceptedAnswer":{"@type":"Answer","text":"Ninguna carta del tarot es intrínsecamente positiva o negativa. ${name} tiene un mensaje que depende del contexto de la tirada y las cartas que le acompañan."}}]}
  </script>
  <style>
${COMMON_CSS}
    .card-hero{text-align:center;padding:2rem 0 1rem}
    .card-hero .card-face{width:140px;height:240px;margin:0 auto 1rem;background:linear-gradient(135deg,#2d1b69,#4a2c8a,#1a0f3c);border-radius:12px;display:flex;flex-direction:column;align-items:center;justify-content:center;color:#e8dff5;box-shadow:0 8px 32px rgba(45,27,105,.4);border:2px solid #7c3aed}
    .card-hero .card-face .num{font-size:.8rem;letter-spacing:.1em;opacity:.7;font-weight:300}
    .card-hero .card-face .symbol{font-size:3rem;margin:.5rem 0}
    .card-hero .card-face .cname{font-size:.85rem;font-weight:600}
    .keywords{display:flex;flex-wrap:wrap;gap:.4rem;justify-content:center;margin:1rem 0}
    .keywords .kw{padding:.25rem .7rem;border-radius:20px;font-size:.75rem;font-weight:500;background:#f3eeff;color:var(--accent);border:1px solid rgba(124,58,237,.15)}
    .meaning-grid{display:grid;grid-template-columns:1fr 1fr;gap:1rem;margin:1rem 0}
    @media(max-width:500px){.meaning-grid{grid-template-columns:1fr}}
    .meaning-card{padding:1.2rem;border-radius:12px;border:1px solid var(--border)}
    .meaning-card.upright{background:#f0fdf4;border-color:#bbf7d0}
    .meaning-card.reversed{background:#fef2f2;border-color:#fecaca}
    .meaning-card h3{font-size:.85rem;font-weight:600;margin-bottom:.4rem}
    .meaning-card.upright h3{color:#16a34a}
    .meaning-card.reversed h3{color:#dc2626}
    .meaning-card p{font-size:.85rem;line-height:1.6;color:var(--muted)}
    .nav-cards{display:flex;justify-content:space-between;margin:1.5rem 0}
    .nav-cards a{color:var(--accent);text-decoration:none;font-size:.85rem;font-weight:500}
  </style>
</head>
<body>
<div class="container">
  <nav class="breadcrumb"><a href="/">Tarot del Día</a> › <a href="/arcanos-mayores">Arcanos Mayores</a> › ${name}</nav>

  <div class="card-hero">
    <div class="card-face">
      <div class="num">ARCANO ${num}</div>
      <div class="symbol">🃏</div>
      <div class="cname">${name}</div>
    </div>
    <h1><span>${name}</span></h1>
    <p style="color:var(--muted);font-size:.9rem">Arcano Mayor ${num}</p>
  </div>

  <div class="keywords">$(IFS=','; for kw in ${keys}; do echo "<span class=\"kw\">${kw## }</span>"; done)</div>

$(ad_block "🔮" "¿Ofreces consultas, cursos o productos esotéricos?" "Tu marca puede aparecer junto a lectores que ya están inmersos en una interpretación de tarot." "Ver espacios y tarifas →")

  <div class="panel">
    <h2>🔮 Descripción de ${name}</h2>
    <p>${desc}</p>
  </div>

  <div class="meaning-grid">
    <div class="meaning-card upright">
      <h3>☀️ Al Derecho</h3>
      <p>${upright}</p>
    </div>
    <div class="meaning-card reversed">
      <h3>🌙 Invertida</h3>
      <p>${reversed}</p>
    </div>
  </div>

  <div class="panel">
    <h2>💕 ${name} en el Amor</h2>
    <p>Cuando ${name} aparece en una tirada sobre relaciones, su mensaje se centra en ${keys}. Al derecho invita a vivir estos aspectos con apertura; invertida sugiere revisar si hay bloqueos en esta área de tu vida. Para un análisis más profundo de tu vida amorosa, consulta la <a href="https://compatibilidad-signos.es/">compatibilidad entre signos</a>.</p>
  </div>

  <div class="panel">
    <h2>💼 ${name} en el Trabajo</h2>
    <p>En el ámbito laboral, ${name} al derecho señala ${upright}. Es un momento para aplicar estas energías en tu carrera. Invertida puede indicar ${reversed}, invitándote a reflexionar sobre tu dirección profesional.</p>
  </div>

  <div class="panel">
    <h2>Cómo integrar el mensaje de ${name}</h2>
    <p>Para interpretar ${name} con precisión, mira primero la pregunta y después la posición de la carta. En una tirada de pasado puede señalar una experiencia que todavía condiciona tu presente; en presente muestra una energía activa; en futuro habla de una tendencia si mantienes el mismo camino.</p>
    <p>Si aparece al derecho, trabaja las claves de ${upright} de forma consciente. Si aparece invertida, no la leas como castigo: suele indicar una energía bloqueada, exagerada o vivida hacia dentro. La utilidad del tarot está en convertir el símbolo en una acción concreta.</p>
    <p>Antes de cerrar la lectura, formula una acción pequeña: una conversación que debes tener, un límite que conviene marcar, una decisión que necesita más información o un descanso que estás posponiendo. El símbolo gana valor cuando se traduce en una conducta observable durante el día.</p>
    <p>También es importante mirar las cartas vecinas. ${name} puede suavizarse, intensificarse o cambiar de matiz según el arcano que aparezca antes y después. Una lectura completa no suma significados sueltos: busca una historia coherente entre pregunta, posición, carta y contexto personal.</p>
    <p>Si la carta se repite en varias tiradas, trátala como un tema abierto. No hace falta repetir la misma pregunta: conviene revisar qué decisión, emoción o patrón sigue pendiente y qué cambio pequeño puedes hacer para mover la situación.</p>
  </div>

  <div class="panel">
    <h2>Preguntas para tu diario de tarot</h2>
    <ul>
      <li>¿Dónde estás viviendo ahora las claves de ${keys}?</li>
      <li>¿Qué decisión cambia si aplicas el mensaje de ${name} con honestidad?</li>
      <li>¿Qué otra carta de la tirada confirma, matiza o contradice esta lectura?</li>
    </ul>
  </div>

$(ad_block "🃏" "Patrocina una lectura de alta atención" "Ubicación destacada entre la interpretación y la llamada a la acción del usuario." "Reservar un banner destacado →")

  <div class="nav-cards">
    <a href="/arcanos-mayores/${MAJOR_SLUGS[$prev_idx]}">← ${MAJOR_NAMES[$prev_idx]}</a>
    <a href="/arcanos-mayores">Todos los Arcanos</a>
    <a href="/arcanos-mayores/${MAJOR_SLUGS[$next_idx]}">${MAJOR_NAMES[$next_idx]} →</a>
  </div>

  <div class="cta-box">
    <h3>🃏 Haz tu tirada de tarot gratis</h3>
    <p>Descubre qué te deparan las cartas hoy con nuestra tirada interactiva de 3 cartas.</p>
    <a href="/">Tirada gratis →</a>
  </div>

$(cluster_recirculation_block "$SITE_KEY")

$(gen_footer)
</div>
</body>
</html>
ENDCARD

  SITEMAP_URLS+="  <url><loc>https://${DOMAIN}${url_path}</loc><lastmod>${TODAY}</lastmod><changefreq>monthly</changefreq><priority>0.7</priority></url>\n"
  PAGE_COUNT=$((PAGE_COUNT + 1))
done
echo "  ✓ ${PAGE_COUNT} major arcana pages"

# ── Arcanos Mayores index ────────────────────────────────────
echo "Generating arcanos-mayores index..."
CARDS_GRID=""
for i in "${!MAJOR_SLUGS[@]}"; do
  CARDS_GRID+="<a class=\"tarot-card\" href=\"/arcanos-mayores/${MAJOR_SLUGS[$i]}\"><span class=\"tnum\">${MAJOR_NUMS[$i]}</span><span class=\"tname\">${MAJOR_NAMES[$i]}</span><span class=\"tkeys\">${MAJOR_KEYS[$i]}</span></a>"
done

cat > "$PUBLIC/arcanos-mayores/index.html" <<ENDMAJOR
<!DOCTYPE html>
<html lang="es">
<head>
$(gen_head "Los 22 Arcanos Mayores del Tarot — Significado Completo" "Guía completa de los 22 Arcanos Mayores del tarot. Significado, interpretación al derecho e invertida de cada carta. De El Loco a El Mundo." "/arcanos-mayores" "content_hub" "hub" "arcanos-mayores")
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":[{"@type":"ListItem","position":1,"name":"Inicio","item":"https://${DOMAIN}/"},{"@type":"ListItem","position":2,"name":"Arcanos Mayores","item":"https://${DOMAIN}/arcanos-mayores"}]}
  </script>
  <style>
${COMMON_CSS}
    .intro{text-align:center;color:var(--muted);font-size:.92rem;line-height:1.6;max-width:620px;margin:0 auto 1.5rem}
    .tarot-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:1rem;margin:1.5rem 0}
    .tarot-card{background:linear-gradient(135deg,#2d1b69,#4a2c8a);border-radius:12px;padding:1.2rem;text-align:center;text-decoration:none;color:#e8dff5;transition:all .2s;box-shadow:0 4px 16px rgba(45,27,105,.3)}
    .tarot-card:hover{transform:translateY(-3px);box-shadow:0 8px 24px rgba(45,27,105,.4)}
    .tarot-card .tnum{font-size:.7rem;letter-spacing:.1em;opacity:.6;display:block}
    .tarot-card .tname{font-family:'Playfair Display',serif;font-weight:700;font-size:.95rem;display:block;margin:.4rem 0}
    .tarot-card .tkeys{font-size:.7rem;opacity:.7;line-height:1.4;display:block}
  </style>
</head>
<body>
<div class="container">
  <nav class="breadcrumb"><a href="/">Tarot del Día</a> › Arcanos Mayores</nav>
  <h1>Los 22 <span>Arcanos Mayores</span></h1>
  <p class="intro">Los Arcanos Mayores representan los grandes arquetipos y lecciones de vida. Cada carta contiene un mensaje profundo sobre tu camino. Pulsa en cualquiera para leer su significado completo.</p>
  <div class="panel">
    <h2>Cómo estudiar los Arcanos Mayores</h2>
    <p>Los Arcanos Mayores forman una secuencia simbólica: empiezan con El Loco, que inicia el viaje sin certezas, y terminan con El Mundo, que integra la experiencia. Leerlos como un recorrido ayuda a entender por qué una carta no es buena o mala por sí misma, sino una etapa concreta de aprendizaje.</p>
    <p>En cada ficha encontrarás significado general, lectura al derecho, lectura invertida, amor, trabajo y preguntas para aplicar el mensaje. Si estás haciendo una tirada, lee primero la carta individual y después vuelve al conjunto para comprobar cómo dialoga con las demás.</p>
    <p>Un buen método de estudio es elegir una carta por semana y observar dónde aparece su energía en decisiones reales. Por ejemplo, El Emperador puede verse en límites y estructura, La Luna en dudas o proyecciones, y La Templanza en procesos que requieren paciencia. Este enfoque evita memorizar listas sin conexión con la experiencia.</p>
    <p>También puedes comparar cartas que parecen opuestas. La Fuerza y El Carro hablan de voluntad, pero una lo hace desde la calma interior y otra desde la dirección externa. La Muerte y La Torre implican cambios, aunque una describe transformación profunda y la otra ruptura repentina. Estas diferencias son las que hacen que una tirada sea rica.</p>
    <p>Si acabas de empezar, trabaja primero con tres posiciones: situación, consejo y tendencia. Cuando ya reconozcas bien los arquetipos, añade cartas de bloqueo, recurso y resultado probable. Así mantienes la lectura clara sin perder profundidad.</p>
    <p>La clave está en observar diferencias concretas. Dos cartas pueden hablar de cambio, pero no del mismo tipo de cambio; dos pueden hablar de amor, pero una señalar deseo y otra compromiso. Cuanto más precisa sea esa distinción, más útil será la lectura.</p>
  </div>

$(ad_block "🃏" "Publicidad destacada para un público espiritual" "Ideal para marcas de tarot, rituales, formación y productos con afinidad esotérica." "Informarme →")

  <div class="tarot-grid">${CARDS_GRID}</div>

  <div class="cta-box">
    <h3>🃏 Haz tu tirada de tarot gratis</h3>
    <p>Descubre qué te dicen los Arcanos Mayores hoy.</p>
    <a href="/">Tirada gratis →</a>
  </div>

$(cluster_recirculation_block "$SITE_KEY")

$(gen_footer)
</div>
</body>
</html>
ENDMAJOR

SITEMAP_URLS+="  <url><loc>https://${DOMAIN}/arcanos-mayores</loc><lastmod>${TODAY}</lastmod><changefreq>monthly</changefreq><priority>0.8</priority></url>\n"
echo "  ✓ arcanos-mayores/index.html"

# ══════════════════════════════════════════════════════════════
# INDEX — Interactive 3-card spread
# ══════════════════════════════════════════════════════════════
echo "Generating index with interactive spread..."

# Build JS card data (major arcana only for the spread)
JS_CARDS="["
for i in "${!MAJOR_SLUGS[@]}"; do
  (( i > 0 )) && JS_CARDS+=","
  JS_CARDS+="{n:\"${MAJOR_NAMES[$i]}\",num:\"${MAJOR_NUMS[$i]}\",slug:\"${MAJOR_SLUGS[$i]}\",keys:\"${MAJOR_KEYS[$i]}\",up:\"${MAJOR_UPRIGHT[$i]}\",rev:\"${MAJOR_REVERSED[$i]}\"}"
done
JS_CARDS+="]"

INDEX_TITLE="Tarot del Día Gratis — Tirada de 3 Cartas"
INDEX_DESC="Haz tu tarot del día gratis con una tirada de 3 cartas. Descubre el mensaje del pasado, presente y futuro con interpretación inmediata."

cat > "$PUBLIC/index.html" <<'ENDINDEX_START'
<!DOCTYPE html>
<html lang="es">
<head>
ENDINDEX_START

gen_head "$INDEX_TITLE" "$INDEX_DESC" "/" "tool_home" "tool" >> "$PUBLIC/index.html"

cat >> "$PUBLIC/index.html" <<ENDINDEX
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"WebSite","name":"Tarot del Día","url":"https://${DOMAIN}/","description":"Tirada de tarot gratis del día con los 22 Arcanos Mayores.","inLanguage":"es"}
  </script>
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"FAQPage","mainEntity":[{"@type":"Question","name":"¿Cómo funciona la tirada de tarot gratis?","acceptedAnswer":{"@type":"Answer","text":"Concéntrate en tu pregunta, pulsa en 3 cartas del mazo y recibe la interpretación de cada arcano para tu situación."}},{"@type":"Question","name":"¿Cuántas veces puedo tirar las cartas?","acceptedAnswer":{"@type":"Answer","text":"Puedes hacer una tirada al día para obtener la mejor guía. Repetir la misma pregunta diluye la energía de la lectura."}},{"@type":"Question","name":"¿Es fiable el tarot por internet?","acceptedAnswer":{"@type":"Answer","text":"El tarot es una herramienta de reflexión e introspección. La selección aleatoria de cartas funciona como espejo de tu subconsciente, igual que en una tirada presencial."}}]}
  </script>
  <style>
${COMMON_CSS}
    .intro{text-align:center;color:var(--muted);font-size:.92rem;line-height:1.6;max-width:600px;margin:0 auto 1.5rem}
    .spread-area{text-align:center;margin:1.5rem 0}
    .deck{display:flex;flex-wrap:wrap;gap:.6rem;justify-content:center;margin:1.5rem 0;max-width:700px;margin-left:auto;margin-right:auto}
    .deck .card-back{width:70px;height:110px;background:linear-gradient(135deg,#2d1b69,#4a2c8a,#1a0f3c);border-radius:8px;cursor:pointer;display:flex;align-items:center;justify-content:center;color:#c084fc;font-size:1.5rem;transition:all .2s;border:2px solid transparent;box-shadow:0 2px 8px rgba(45,27,105,.3)}
    .deck .card-back:hover{transform:translateY(-4px);border-color:#c084fc;box-shadow:0 6px 20px rgba(45,27,105,.4)}
    .deck .card-back.picked{opacity:.3;pointer-events:none}
    .chosen{display:flex;gap:1.2rem;justify-content:center;margin:2rem 0;flex-wrap:wrap}
    .chosen .slot{width:140px;min-height:200px;border:2px dashed var(--border);border-radius:12px;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:.8rem;transition:all .3s}
    .chosen .slot.filled{border:2px solid var(--accent);background:linear-gradient(135deg,#2d1b69,#4a2c8a);color:#e8dff5}
    .chosen .slot .pos{font-size:.7rem;text-transform:uppercase;letter-spacing:.08em;color:var(--muted);margin-bottom:.3rem}
    .chosen .slot.filled .pos{color:#c084fc}
    .chosen .slot .cname{font-family:'Playfair Display',serif;font-size:.85rem;font-weight:700;margin:.3rem 0}
    .chosen .slot .cnum{font-size:.7rem;opacity:.7}
    .chosen .slot .reversed-tag{font-size:.65rem;color:#f97316;margin-top:.2rem}
    .result{display:none;margin:1.5rem 0}
    .result.show{display:block}
    .result .reading{background:var(--surface);border:1px solid var(--border);border-radius:16px;padding:1.5rem;margin:.8rem 0;box-shadow:var(--shadow)}
    .result .reading h3{font-family:'Playfair Display',serif;font-size:1rem;margin-bottom:.5rem;color:var(--accent)}
    .result .reading p{line-height:1.7;color:var(--muted);font-size:.9rem}
    .result .reading .link{display:inline-block;margin-top:.5rem;color:var(--accent);text-decoration:none;font-size:.85rem;font-weight:500}
    .btn-reset{margin-top:1rem;padding:.5rem 1.5rem;background:var(--bg);color:var(--accent);border:1px solid var(--border);border-radius:10px;font-weight:600;cursor:pointer;font-family:inherit;font-size:.85rem}
    .seo-text{margin:2rem 0}
    .seo-text h2{font-size:1.1rem;margin:1.2rem 0 .5rem}
    .seo-text p{line-height:1.7;color:var(--muted);font-size:.9rem;margin-bottom:.5rem}
  </style>
</head>
<body>
<div class="container">
  <header style="text-align:center;padding:1.5rem 0 .5rem">
    <div style="font-size:.75rem;letter-spacing:.15em;text-transform:uppercase;color:var(--accent);font-weight:600">Tarot</div>
    <h1><span>Tarot del Día</span></h1>
    <p class="intro">Concéntrate en tu pregunta, elige 3 cartas del mazo y descubre el mensaje que los Arcanos Mayores tienen para ti hoy.</p>
  </header>

  <div class="spread-area">
    <p style="font-size:.85rem;color:var(--accent);font-weight:600;margin-bottom:.5rem" id="instruction">🃏 Elige 3 cartas del mazo</p>
    <div class="chosen">
      <div class="slot" id="slot0"><span class="pos">Pasado</span><span style="font-size:1.5rem;color:var(--border)">?</span></div>
      <div class="slot" id="slot1"><span class="pos">Presente</span><span style="font-size:1.5rem;color:var(--border)">?</span></div>
      <div class="slot" id="slot2"><span class="pos">Futuro</span><span style="font-size:1.5rem;color:var(--border)">?</span></div>
    </div>
    <div class="deck" id="deck"></div>
  </div>

$(ad_block "🔮" "¿Quieres llegar a usuarios que consultan tarot hoy?" "Espacio visible entre la tirada interactiva y la lectura, con contexto perfecto para conversión." "Ver espacios y tarifas →")

  <div class="result" id="result"></div>

  <div class="cta-box">
    <h3>🌟 Profundiza con tu carta astral</h3>
    <p>Descubre cómo los planetas de tu carta natal están influenciando estos mensajes del tarot.</p>
    <a href="https://carta-astral-gratis.es/">Calcular mi carta astral gratis →</a>
  </div>

  <div class="panel" style="text-align:center">
    <h2>Explora los Arcanos</h2>
    <p><a href="/arcanos-mayores" style="color:var(--accent);font-weight:600;text-decoration:none">Ver los 22 Arcanos Mayores →</a></p>
  </div>

  <div class="seo-text panel">
    <h2>¿Qué es el Tarot del Día?</h2>
    <p>El tarot del día es una tirada rápida de 3 cartas que te ofrece una guía para las próximas horas. Las tres posiciones (Pasado, Presente y Futuro) te ayudan a comprender de dónde vienes, dónde estás y hacia dónde te diriges.</p>
    <p>No está pensado para tomar decisiones por ti, sino para ordenar la intuición. Si una carta señala tensión, úsala para detectar dónde necesitas más claridad; si señala apertura, pregúntate qué oportunidad concreta puedes aprovechar hoy.</p>
    <p>La lectura funciona mejor si partes de una pregunta sencilla y verificable. En vez de preguntar qué ocurrirá en general, prueba con qué necesito ver hoy, qué actitud me ayuda o qué bloqueo conviene reconocer.</p>

    <h2>¿Cómo hacer una tirada de tarot gratis?</h2>
    <p>Relájate, formula mentalmente tu pregunta o intención. Pulsa en 3 cartas del mazo para revelarlas. Cada carta puede salir al derecho (energía fluida) o invertida (energía bloqueada o interiorizada). Lee el mensaje completo y reflexiona sobre cómo se aplica a tu situación actual.</p>

    <h2>Los 22 Arcanos Mayores</h2>
    <p>Los Arcanos Mayores son las 22 cartas más poderosas del tarot. Representan arquetipos universales que reflejan las grandes lecciones y transiciones de la vida. Desde El Loco (el inicio del viaje) hasta El Mundo (la completud), cada arcano contiene una sabiduría ancestral que trasciende culturas y épocas.</p>
    <p>En una lectura diaria, los Arcanos Mayores suelen señalar temas de fondo más que detalles menores. Hablan de decisiones, cierres, aprendizajes, deseos, bloqueos y cambios de perspectiva. Por eso conviene leerlos despacio y relacionarlos con una situación concreta, no como frases aisladas.</p>

    <h2>Tarot y astrología</h2>
    <p>Cada Arcano Mayor está conectado con un signo zodiacal o planeta. Por eso, combinar tu <a href="https://carta-astral-gratis.es/">carta astral</a> con el tarot te da una perspectiva mucho más rica. La <a href="https://compatibilidad-signos.es/">compatibilidad de signos</a> también puede enriquecer las lecturas sobre relaciones.</p>
    <p>Si conoces tu carta natal, compara la carta que sale con los temas activos de tu Sol, Luna y Ascendente. Esa lectura cruzada permite distinguir si el mensaje habla de identidad, emoción, vínculo, acción o comunicación.</p>
    <p>Después de la tirada, guarda una nota breve con la pregunta, las cartas y lo que ocurrió durante el día. Con el tiempo podrás distinguir mejor cuándo una carta habla de un hecho externo y cuándo refleja un estado interno que conviene ordenar.</p>
    <p>La tirada gana precisión cuando no repites la misma pregunta varias veces. Si necesitas más claridad, cambia el enfoque: pregunta qué puedes observar, qué recurso tienes disponible o qué conversación conviene preparar.</p>
  </div>

$(ad_block "✨" "Patrocina espacios de alta afinidad" "Venta directa: más control, más recuerdo de marca y mayor contexto editorial." "Ver espacios →")

$(cluster_recirculation_block "$SITE_KEY")

$(gen_footer)
</div>

<script>
(function(){
  const CARDS=${JS_CARDS};
  const POS=['Pasado','Presente','Futuro'];
  let chosen=[];
  let started=false;
  const deck=document.getElementById('deck');
  const shuffled=[...Array(CARDS.length).keys()].sort(()=>Math.random()-.5);

  shuffled.forEach((ci,i)=>{
    const el=document.createElement('div');
    el.className='card-back';
    el.innerHTML='🂠';
    el.dataset.idx=ci;
    el.addEventListener('click',()=>pickCard(el,ci));
    deck.appendChild(el);
  });

  function pickCard(el,ci){
    if(chosen.length>=3)return;
    if(!started){
      started=true;
      if(window.clusterTrack)window.clusterTrack('tool_start',{tool_action:'tarot_draw_start'});
    }
    el.classList.add('picked');
    const isReversed=Math.random()<.35;
    const card={...CARDS[ci],reversed:isReversed};
    chosen.push(card);
    const slot=document.getElementById('slot'+chosen.length-1+'')||document.getElementById('slot'+(chosen.length-1));
    slot.classList.add('filled');
    slot.innerHTML='<span class="pos">'+POS[chosen.length-1]+'</span><span class="cnum">'+card.num+'</span><span class="cname">'+card.n+'</span>'+(isReversed?'<span class="reversed-tag">↕ Invertida</span>':'');
    if(chosen.length===3)showResult();
  }

  function showResult(){
    document.getElementById('instruction').textContent='✨ Tu lectura está lista';
    const res=document.getElementById('result');
    let html='';
    if(window.clusterTrack){
      window.clusterTrack('tarot_reading_complete',{
        cards_chosen:String(chosen.length),
        first_card:chosen[0]?.slug||'',
        second_card:chosen[1]?.slug||'',
        third_card:chosen[2]?.slug||''
      });
    }
    chosen.forEach((c,i)=>{
      const meaning=c.reversed?c.rev:c.up;
      html+='<div class="reading"><h3>'+POS[i]+': '+c.n+' ('+c.num+')'+(c.reversed?' ↕ Invertida':'')+'</h3><p>'+meaning+'</p><a class="link" href="/arcanos-mayores/'+c.slug+'">Leer significado completo de '+c.n+' →</a></div>';
    });
    html+='<div style="text-align:center"><button class="btn-reset" onclick="location.reload()">🔄 Nueva tirada</button></div>';
    res.innerHTML=html;
    res.classList.add('show');
  }
})();
</script>
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
  <title>Página no encontrada — Tarot del Día</title>
  <meta name="robots" content="noindex">
$(canonical_host_redirect_script "$DOMAIN")
  <style>${COMMON_CSS}</style>
</head>
<body>
<div class="container" style="text-align:center;padding:4rem 1rem">
  <div style="font-size:4rem">🃏</div>
  <h1>Las cartas no encuentran esta página</h1>
  <p style="color:var(--muted);margin:1rem 0">Vuelve al inicio para hacer tu tirada del día.</p>
  <a href="/" style="display:inline-block;padding:.6rem 1.5rem;background:var(--accent);color:#fff;border-radius:10px;text-decoration:none;font-weight:600">← Tirada de tarot gratis</a>
</div>
</body>
</html>
END404

echo "  ✓ Static files"
bash "$REPO_ROOT/scripts/generate-legal-pages.sh" "$SITE_KEY"
echo "Done! $((PAGE_COUNT + 1)) pages + index in $PUBLIC"
