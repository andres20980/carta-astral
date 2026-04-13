#!/usr/bin/env bash
set -euo pipefail
# Generate 144 compatibility pages + index + sitemap for compatibilidad-signos.es

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SITE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBLIC="$SITE_DIR/public"
REPO_ROOT="$(cd "$SITE_DIR/../.." && pwd)"

source "$REPO_ROOT/shared/config.sh"

SITE_KEY="compatibilidad-signos"
DOMAIN="${DOMAINS[$SITE_KEY]}"
GA4="${GA4_IDS[$SITE_KEY]}"
TODAY=$(date +%Y-%m-%d)
AD_CSS="$(ad_css)"
CLUSTER_CSS="$(cluster_css)"

mkdir -p "$PUBLIC"

# ── Sign data ────────────────────────────────────────────────
SLUGS=(aries tauro geminis cancer leo virgo libra escorpio sagitario capricornio acuario piscis)
declare -A NAME=([aries]="Aries" [tauro]="Tauro" [geminis]="Géminis" [cancer]="Cáncer" [leo]="Leo" [virgo]="Virgo" [libra]="Libra" [escorpio]="Escorpio" [sagitario]="Sagitario" [capricornio]="Capricornio" [acuario]="Acuario" [piscis]="Piscis")
declare -A GLYPH=([aries]="♈" [tauro]="♉" [geminis]="♊" [cancer]="♋" [leo]="♌" [virgo]="♍" [libra]="♎" [escorpio]="♏" [sagitario]="♐" [capricornio]="♑" [acuario]="♒" [piscis]="♓")
declare -A ELEMENT=([aries]="Fuego" [tauro]="Tierra" [geminis]="Aire" [cancer]="Agua" [leo]="Fuego" [virgo]="Tierra" [libra]="Aire" [escorpio]="Agua" [sagitario]="Fuego" [capricornio]="Tierra" [acuario]="Aire" [piscis]="Agua")
declare -A RULER=([aries]="Marte" [tauro]="Venus" [geminis]="Mercurio" [cancer]="Luna" [leo]="Sol" [virgo]="Mercurio" [libra]="Venus" [escorpio]="Plutón" [sagitario]="Júpiter" [capricornio]="Saturno" [acuario]="Urano" [piscis]="Neptuno")
declare -A MODALITY=([aries]="Cardinal" [tauro]="Fijo" [geminis]="Mutable" [cancer]="Cardinal" [leo]="Fijo" [virgo]="Mutable" [libra]="Cardinal" [escorpio]="Fijo" [sagitario]="Mutable" [capricornio]="Cardinal" [acuario]="Fijo" [piscis]="Mutable")

# ── Compatibility scoring ────────────────────────────────────
element_base() {
  local e1="$1" e2="$2"
  [[ "$e1" == "$e2" ]] && echo 82 && return
  case "${e1}-${e2}" in
    Fuego-Aire|Aire-Fuego) echo 78;;
    Tierra-Agua|Agua-Tierra) echo 76;;
    Fuego-Tierra|Tierra-Fuego) echo 45;;
    Fuego-Agua|Agua-Fuego) echo 40;;
    Aire-Tierra|Tierra-Aire) echo 48;;
    Aire-Agua|Agua-Aire) echo 55;;
    *) echo 50;;
  esac
}

modality_mod() {
  local m1="$1" m2="$2"
  [[ "$m1" == "$m2" ]] && echo -3 && return
  case "${m1}-${m2}" in
    Cardinal-Mutable|Mutable-Cardinal) echo 5;;
    Fijo-Mutable|Mutable-Fijo) echo 4;;
    Cardinal-Fijo|Fijo-Cardinal) echo -1;;
    *) echo 0;;
  esac
}

# Deterministic per-pair modifier from slug hash
pair_mod() {
  local hash
  hash=$(echo -n "${1}-${2}" | cksum | cut -d' ' -f1)
  echo $(( (hash % 13) - 6 ))  # range -6..+6
}

calc_score() {
  local s1="$1" s2="$2"
  local base mod_m mod_p score
  base=$(element_base "${ELEMENT[$s1]}" "${ELEMENT[$s2]}")
  mod_m=$(modality_mod "${MODALITY[$s1]}" "${MODALITY[$s2]}")
  mod_p=$(pair_mod "$s1" "$s2")
  score=$(( base + mod_m + mod_p ))
  (( score > 98 )) && score=98
  (( score < 25 )) && score=25
  echo "$score"
}

score_label() {
  local s=$1
  if (( s >= 80 )); then echo "Muy Alta"
  elif (( s >= 65 )); then echo "Alta"
  elif (( s >= 50 )); then echo "Media"
  elif (( s >= 35 )); then echo "Baja"
  else echo "Muy Baja"
  fi
}

score_emoji() {
  local s=$1
  if (( s >= 80 )); then echo "🔥"
  elif (( s >= 65 )); then echo "✨"
  elif (( s >= 50 )); then echo "⚖️"
  elif (( s >= 35 )); then echo "🌧️"
  else echo "❄️"
  fi
}

# ── Element pair descriptions ────────────────────────────────
element_desc() {
  local e1="$1" e2="$2"
  [[ "$e1" == "$e2" ]] && { echo "Al compartir el elemento ${e1}, existe una comprensión instintiva entre ambos. Se entienden sin palabras y comparten una misma forma de procesar la vida. El riesgo es caer en una zona de confort o potenciar los excesos del elemento."; return; }
  case "${e1}-${e2}" in
    Fuego-Aire|Aire-Fuego) echo "El Aire alimenta al Fuego, creando una conexión vibrante y estimulante. La comunicación es fluida, las ideas se encienden mutuamente y la pasión se aviva con cada conversación. Una de las combinaciones más dinámicas del zodíaco.";;
    Tierra-Agua|Agua-Tierra) echo "La Tierra contiene al Agua y el Agua nutre la Tierra. Es una combinación naturalmente fértil: estabilidad emocional, cuidado mutuo y construcción paciente de algo duradero. Ambos valoran la seguridad.";;
    Fuego-Tierra|Tierra-Fuego) echo "El Fuego quiere moverse rápido; la Tierra necesita tiempo. Esta diferencia de ritmo genera fricción, pero también complementariedad: el Fuego motiva a la Tierra y la Tierra da estructura al Fuego.";;
    Fuego-Agua|Agua-Fuego) echo "El Fuego evapora al Agua, el Agua apaga al Fuego. Esta combinación requiere esfuerzo consciente: las emociones profundas del Agua pueden sofocar al Fuego, y la intensidad del Fuego puede abrumar al Agua.";;
    Aire-Tierra|Tierra-Aire) echo "El Aire vuela libre mientras la Tierra busca raíces. Son mundos diferentes que pueden complementarse si el Aire aporta ideas frescas y la Tierra las materializa. El reto es encontrar terreno común.";;
    Aire-Agua|Agua-Aire) echo "El Aire racionaliza lo que el Agua siente. Pueden aprender mucho el uno del otro: el Aire ayuda al Agua a ganar perspectiva y el Agua enseña al Aire la profundidad emocional. Requiere paciencia mutua.";;
    *) echo "Una combinación con matices interesantes que depende de otros factores de la carta natal para desarrollar su máximo potencial.";;
  esac
}

# ── Generate common <head> ───────────────────────────────────
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
  <script>if(location.hostname.endsWith('.web.app'))location.replace('https://${DOMAIN}'+location.pathname+location.search);</script>
$(ga4_head_snippet "$GA4" "$SITE_KEY" "$page_type" "$content_group" "$entity_slug")
  <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${ADSENSE_PUB}" crossorigin="anonymous"></script>
  <link rel="preconnect" href="https://pagead2.googlesyndication.com">
  <link rel="dns-prefetch" href="https://pagead2.googlesyndication.com">
ENDHEAD
}

# ── Common CSS ───────────────────────────────────────────────
COMMON_CSS="
    ${CSS_VARS}
    *{margin:0;padding:0;box-sizing:border-box}
    body{font-family:'Inter',system-ui,sans-serif;background:var(--bg);color:var(--text);min-height:100vh}
    .container{max-width:820px;margin:0 auto;padding:1.5rem}
    .breadcrumb{font-size:.8rem;color:var(--muted);margin-bottom:1.5rem}
    .breadcrumb a{color:var(--accent);text-decoration:none}
    h1{font-family:'Playfair Display',serif;font-size:1.9rem;text-align:center;margin:.5rem 0 .3rem}
    h1 span{background:var(--gradient);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
    h2{font-family:'Playfair Display',serif;font-size:1.15rem;color:var(--text);margin-bottom:.7rem}
    .panel{background:var(--surface);border:1px solid var(--border);border-radius:16px;padding:1.6rem;box-shadow:var(--shadow);margin-bottom:1.2rem}
    .panel p,.panel li{line-height:1.7;color:var(--muted);font-size:.9rem}
    .panel ul{padding-left:1.2rem;margin:.5rem 0}
    .score-hero{text-align:center;padding:1.5rem 0 1rem}
    .score-hero .glyphs{font-size:2.8rem;letter-spacing:.5rem}
    .score-hero .pct{font-family:'Playfair Display',serif;font-size:3rem;font-weight:700;color:var(--accent);margin:.3rem 0}
    .score-hero .label{font-size:.9rem;color:var(--muted)}
    .meter{height:12px;background:var(--border);border-radius:6px;overflow:hidden;margin:.8rem 0}
    .meter .fill{height:100%;border-radius:6px;background:var(--gradient);transition:width .6s}
    .meta-row{display:flex;gap:.6rem;justify-content:center;flex-wrap:wrap;margin:.8rem 0}
    .tag{padding:.3rem .8rem;border-radius:20px;font-size:.75rem;font-weight:500;background:var(--surface);border:1px solid var(--border)}
    .cta-box{text-align:center;padding:1.8rem;background:linear-gradient(135deg,#f3eeff 0%,#fef9ee 100%);border-radius:16px;margin:1.5rem 0}
    .cta-box h3{font-family:'Playfair Display',serif;font-size:1.05rem;margin-bottom:.4rem}
    .cta-box p{color:var(--muted);font-size:.88rem;margin-bottom:.8rem}
    .cta-box a{display:inline-block;padding:.6rem 1.4rem;background:var(--accent);color:#fff;font-weight:600;border-radius:10px;text-decoration:none;font-size:.88rem;box-shadow:0 4px 14px rgba(124,58,237,.3);transition:all .2s}
    .cta-box a:hover{background:#6d28d9;transform:translateY(-1px)}
    .network{text-align:center;font-size:.75rem;color:var(--muted);margin-top:1rem}
    .network a{color:var(--accent);text-decoration:none}
    footer{text-align:center;padding:2rem 1rem;font-size:.75rem;color:var(--muted);border-top:1px solid var(--border);margin-top:2rem}
    footer a{color:var(--accent);text-decoration:none}
${AD_CSS}
${CLUSTER_CSS}
"

# ── Cross-links ──────────────────────────────────────────────
CROSSLINKS_HTML=$(crosslink_footer "$SITE_KEY")

# ── Generate footer ──────────────────────────────────────────
gen_footer() {
  cat <<ENDFOOTER
<footer>
  <p>© $(date +%Y) Compatibilidad Signos — Herramienta gratuita de astrología</p>
  <p><a href="/privacy">Privacidad</a> · <a href="/terms">Términos</a></p>
  $(footer_publicidad_line "$SITE_KEY")
  ${CROSSLINKS_HTML}
</footer>
ENDFOOTER
}

# ══════════════════════════════════════════════════════════════
# GENERATE PAIR PAGES
# ══════════════════════════════════════════════════════════════
echo "Generating 144 compatibility pages..."
mkdir -p "$PUBLIC"

SITEMAP_URLS=""
PAGE_COUNT=0
PAIR_TITLE_TEMPLATE="Compatibilidad {{name1}} y {{name2}} {{glyphs}} — {{score}}% {{label}}"
PAIR_DESC_TEMPLATE="¿Son compatibles {{name1}} y {{name2}}? Descubre su afinidad amorosa ({{score}}%), fortalezas, retos y cómo se complementan según sus elementos y planetas regentes."

for s1 in "${SLUGS[@]}"; do
  for s2 in "${SLUGS[@]}"; do
    n1="${NAME[$s1]}" n2="${NAME[$s2]}"
    g1="${GLYPH[$s1]}" g2="${GLYPH[$s2]}"
    e1="${ELEMENT[$s1]}" e2="${ELEMENT[$s2]}"
    r1="${RULER[$s1]}" r2="${RULER[$s2]}"

    score=$(calc_score "$s1" "$s2")
    label=$(score_label "$score")
    emoji=$(score_emoji "$score")
    elem_text=$(element_desc "$e1" "$e2")

    slug_page="${s1}-${s2}"
    file="$PUBLIC/${slug_page}.html"
    url_path="/${slug_page}"

    title="${PAIR_TITLE_TEMPLATE//\{\{name1\}\}/$n1}"
    title="${title//\{\{name2\}\}/$n2}"
    title="${title//\{\{glyphs\}\}/$g1$g2}"
    title="${title//\{\{score\}\}/$score}"
    title="${title//\{\{label\}\}/$label}"

    desc="${PAIR_DESC_TEMPLATE//\{\{name1\}\}/$n1}"
    desc="${desc//\{\{name2\}\}/$n2}"
    desc="${desc//\{\{score\}\}/$score}"

    cat > "$file" <<ENDHTML
<!DOCTYPE html>
<html lang="es">
<head>
$(gen_head "$title" "$desc" "$url_path" "compatibility_landing" "long_tail" "$slug_page")
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"Article","headline":"Compatibilidad ${n1} y ${n2}","description":"${desc}","author":{"@type":"Organization","name":"Compatibilidad Signos"},"publisher":{"@type":"Organization","name":"Compatibilidad Signos","url":"https://${DOMAIN}/"},"mainEntityOfPage":"https://${DOMAIN}${url_path}","inLanguage":"es"}
  </script>
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":[{"@type":"ListItem","position":1,"name":"Inicio","item":"https://${DOMAIN}/"},{"@type":"ListItem","position":2,"name":"${n1} y ${n2}","item":"https://${DOMAIN}${url_path}"}]}
  </script>
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"FAQPage","mainEntity":[{"@type":"Question","name":"¿Son compatibles ${n1} y ${n2}?","acceptedAnswer":{"@type":"Answer","text":"La compatibilidad entre ${n1} y ${n2} es del ${score}% (${label}). ${n1} es ${e1} regido por ${r1}, mientras que ${n2} es ${e2} regido por ${r2}."}},{"@type":"Question","name":"¿Qué elemento comparten ${n1} y ${n2}?","acceptedAnswer":{"@type":"Answer","text":"${n1} pertenece al elemento ${e1} y ${n2} al elemento ${e2}."}}]}
  </script>
  <style>${COMMON_CSS}</style>
</head>
<body>
<div class="container">
  <nav class="breadcrumb"><a href="/">Compatibilidad Signos</a> › ${n1} y ${n2}</nav>

  <div class="score-hero">
    <div class="glyphs">${g1} ${g2}</div>
    <h1><span>Compatibilidad ${n1} y ${n2}</span></h1>
    <div class="pct">${emoji} ${score}%</div>
    <div class="label">Afinidad ${label}</div>
    <div class="meter"><div class="fill" style="width:${score}%"></div></div>
  </div>

  <div class="meta-row">
    <span class="tag">${g1} ${n1} · ${e1} · ${r1}</span>
    <span class="tag">${g2} ${n2} · ${e2} · ${r2}</span>
  </div>

$(ad_block "❤" "¿Tienes una app de citas, consulta o regalo romantico?" "Aparece ante usuarios que ya estan leyendo una combinacion concreta y tienen intencion alta de relacion." "Ver espacios y tarifas ->")

  <div class="panel">
    <h2>${g1}${g2} Análisis de Compatibilidad</h2>
    <p>${elem_text}</p>
    <p>Con ${r1} (regente de ${n1}) y ${r2} (regente de ${n2}) en juego, la dinámica planetaria añade matices importantes. ${r1} aporta la energía de ${n1} en la relación, mientras ${r2} trae la esencia de ${n2}.</p>
  </div>

  <div class="panel">
    <h2>💪 Fortalezas de la pareja ${n1}–${n2}</h2>
    <ul>
      <li>${n1} aporta la energía de ${e1}: $([ "$e1" = "Fuego" ] && echo "pasión, iniciativa y entusiasmo" || [ "$e1" = "Tierra" ] && echo "estabilidad, constancia y sentido práctico" || [ "$e1" = "Aire" ] && echo "comunicación, ideas y perspectiva" || echo "intuición, empatía y profundidad emocional")</li>
      <li>${n2} complementa con ${e2}: $([ "$e2" = "Fuego" ] && echo "motivación, coraje y vitalidad" || [ "$e2" = "Tierra" ] && echo "estructura, paciencia y fiabilidad" || [ "$e2" = "Aire" ] && echo "flexibilidad, sociabilidad y creatividad" || echo "sensibilidad, cuidado y conexión emocional")</li>
      <li>La combinación ${MODALITY[$s1]}–${MODALITY[$s2]} $([ "${MODALITY[$s1]}" = "${MODALITY[$s2]}" ] && echo "genera comprensión en el modo de actuar, aunque puede crear competencia" || echo "aporta equilibrio: diferentes ritmos que se complementan")</li>
    </ul>
  </div>

  <div class="panel">
    <h2>⚠️ Retos a trabajar</h2>
    <ul>
      <li>$([ "$e1" = "$e2" ] && echo "Al ser ambos ${e1}, pueden potenciar los excesos del elemento y caer en dinámicas repetitivas" || echo "La diferencia ${e1}–${e2} requiere esfuerzo para entender los ritmos y necesidades del otro")</li>
      <li>${n1} necesita $([ "$e1" = "Fuego" ] && echo "acción y libertad" || [ "$e1" = "Tierra" ] && echo "seguridad y previsibilidad" || [ "$e1" = "Aire" ] && echo "espacio mental y variedad" || echo "conexión emocional profunda"), mientras ${n2} prioriza $([ "$e2" = "Fuego" ] && echo "la independencia y la aventura" || [ "$e2" = "Tierra" ] && echo "la estabilidad y lo tangible" || [ "$e2" = "Aire" ] && echo "la comunicación y lo social" || echo "la intimidad y lo intuitivo")</li>
      <li>La comunicación entre ${r1} y ${r2} puede generar $(( score > 60 )) && echo "roces menores que se resuelven con diálogo" || echo "malentendidos que requieren paciencia y voluntad de escucha"</li>
    </ul>
  </div>

  <div class="panel">
    <h2>🌙 En la Carta Natal</h2>
    <p>La compatibilidad real va más allá del signo solar. Si tienes Luna, Venus o Marte en ${n2}, tu conexión con personas ${n2} será más intensa. Calcula tu carta astral completa para descubrir todas tus compatibilidades planetarias.</p>
  </div>

$(ad_block "✦" "Patrocina una de las combinaciones mas buscadas" "Ideal para marcas de pareja, coaching, joyeria y bienestar emocional con mensaje contextual." "Reservar un banner premium ->")

  <div class="cta-box">
    <h3>🔮 Descubre tu carta astral completa</h3>
    <p>Calcula tu mapa natal con hora y lugar exactos. Descubre tu Luna, Venus, Marte y todos los aspectos que influyen en tus relaciones.</p>
    <a href="https://carta-astral-gratis.es/" rel="noopener">Calcular mi carta astral gratis →</a>
  </div>

  <div class="panel">
    <h2>Otras compatibilidades de ${n1}</h2>
    <p style="display:flex;flex-wrap:wrap;gap:.4rem">$(for s in "${SLUGS[@]}"; do [[ "$s" == "$s2" ]] && continue; printf '<a href="/%s-%s" style="padding:.25rem .6rem;background:var(--bg);border:1px solid var(--border);border-radius:8px;text-decoration:none;color:var(--accent);font-size:.8rem">%s %s</a>' "$s1" "$s" "${GLYPH[$s]}" "${NAME[$s]}"; done)</p>
  </div>

$(cluster_recirculation_block "$SITE_KEY")

$(gen_footer)
</div>
</body>
</html>
ENDHTML

    SITEMAP_URLS+="  <url><loc>https://${DOMAIN}${url_path}</loc><lastmod>${TODAY}</lastmod><changefreq>monthly</changefreq><priority>0.7</priority></url>\n"
    PAGE_COUNT=$((PAGE_COUNT + 1))
  done
done
echo "  ✓ ${PAGE_COUNT} pair pages generated"

# ══════════════════════════════════════════════════════════════
# INDEX PAGE
# ══════════════════════════════════════════════════════════════
echo "Generating index..."

INDEX_TITLE="Compatibilidad de Signos Zodiacales — Calculadora Gratis"
INDEX_DESC="Descubre la compatibilidad entre los 12 signos del zodíaco. 144 combinaciones analizadas: fortalezas, retos y porcentaje de afinidad. Herramienta gratuita."

# Build the 12x12 grid rows
GRID_ROWS=""
for s1 in "${SLUGS[@]}"; do
  GRID_ROWS+="<tr><th class=\"row-h\">${GLYPH[$s1]}<br><span>${NAME[$s1]}</span></th>"
  for s2 in "${SLUGS[@]}"; do
    sc=$(calc_score "$s1" "$s2")
    lbl=$(score_label "$sc")
    # Color class based on score
    if (( sc >= 75 )); then cls="high"
    elif (( sc >= 55 )); then cls="mid"
    else cls="low"
    fi
    GRID_ROWS+="<td class=\"cell ${cls}\"><a href=\"/${s1}-${s2}\">${sc}%</a></td>"
  done
  GRID_ROWS+="</tr>"
done

cat > "$PUBLIC/index.html" <<ENDINDEX
<!DOCTYPE html>
<html lang="es">
<head>
$(gen_head "$INDEX_TITLE" "$INDEX_DESC" "/" "tool_home" "tool")
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"WebSite","name":"Compatibilidad de Signos","url":"https://${DOMAIN}/","description":"${INDEX_DESC}","inLanguage":"es"}
  </script>
  <script type="application/ld+json">
  {"@context":"https://schema.org","@type":"FAQPage","mainEntity":[{"@type":"Question","name":"¿Cómo se calcula la compatibilidad entre signos?","acceptedAnswer":{"@type":"Answer","text":"La compatibilidad se basa en el elemento (Fuego, Tierra, Aire, Agua), la modalidad (Cardinal, Fijo, Mutable) y los planetas regentes de cada signo. Se analizan las sinergias y tensiones naturales entre estos factores."}},{"@type":"Question","name":"¿Qué signos son más compatibles entre sí?","acceptedAnswer":{"@type":"Answer","text":"Los signos del mismo elemento suelen tener alta compatibilidad (Fuego con Fuego, Tierra con Tierra). También los elementos complementarios: Fuego con Aire, y Tierra con Agua."}}]}
  </script>
  <style>
${COMMON_CSS}
    .intro{text-align:center;color:var(--muted);font-size:.92rem;line-height:1.6;max-width:620px;margin:0 auto 1.5rem}
    .calc{background:var(--surface);border:1px solid var(--border);border-radius:16px;padding:1.5rem;box-shadow:var(--shadow);margin-bottom:2rem;text-align:center}
    .calc select{padding:.5rem 1rem;border:1px solid var(--border);border-radius:8px;font-size:.95rem;font-family:inherit;background:var(--bg);margin:.3rem}
    .calc .btn{margin-top:.8rem;padding:.6rem 2rem;background:var(--accent);color:#fff;border:none;border-radius:10px;font-weight:600;cursor:pointer;font-size:.9rem}
    .calc .btn:hover{background:#6d28d9}
    .grid-wrap{overflow-x:auto;margin:1.5rem 0}
    table{border-collapse:collapse;font-size:.72rem;width:100%;min-width:700px}
    th,td{padding:.35rem .2rem;text-align:center;border:1px solid var(--border)}
    thead th{background:#f3eeff;color:var(--accent);font-size:.65rem;writing-mode:vertical-lr;text-orientation:mixed;height:5rem;min-width:2.5rem}
    .row-h{background:#f3eeff;color:var(--accent);font-weight:600;white-space:nowrap;padding:.3rem .5rem}
    .row-h span{display:block;font-size:.6rem;font-weight:400}
    .cell a{text-decoration:none;display:block;padding:.2rem;border-radius:4px;font-weight:600;transition:all .15s}
    .cell a:hover{transform:scale(1.1)}
    .cell.high a{color:#16a34a;background:#f0fdf4}
    .cell.mid a{color:#9a7410;background:#fef9ee}
    .cell.low a{color:#dc2626;background:#fef2f2}
    .seo-text{margin:2rem 0}
    .seo-text h2{font-size:1.2rem;margin:1.5rem 0 .6rem}
    .seo-text p,.seo-text li{line-height:1.7;color:var(--muted);font-size:.9rem;margin-bottom:.5rem}
    .seo-text ul{padding-left:1.2rem}
  </style>
</head>
<body>
<div class="container">
  <header style="text-align:center;padding:1.5rem 0 .5rem">
    <div style="font-size:.75rem;letter-spacing:.15em;text-transform:uppercase;color:var(--accent);font-weight:600">Astrología</div>
    <h1><span>Compatibilidad de Signos</span></h1>
    <p class="intro">Descubre el grado de afinidad entre los 12 signos del zodíaco. Selecciona dos signos o explora la tabla completa con las 144 combinaciones.</p>
  </header>

  <div class="calc">
    <h2 style="margin-bottom:.6rem">Calculadora Rápida</h2>
    <div>
      <select id="s1">$(for s in "${SLUGS[@]}"; do echo "<option value=\"$s\">${GLYPH[$s]} ${NAME[$s]}</option>"; done)</select>
      <span style="font-size:1.2rem;color:var(--accent)">❤️</span>
      <select id="s2">$(for s in "${SLUGS[@]}"; do echo "<option value=\"$s\">${GLYPH[$s]} ${NAME[$s]}</option>"; done)</select>
    </div>
    <button class="btn" onclick="openCompatibilityFromHome()">Ver compatibilidad →</button>
  </div>

$(ad_block "❤" "Publicidad premium en un nicho de amor y afinidad" "La ubicacion mas visible para captar usuarios antes de que profundicen en la tabla completa." "Informarme ->")

  <h2 style="text-align:center">Tabla de Compatibilidad Completa</h2>
  <div class="grid-wrap">
  <table>
    <thead><tr><th></th>$(for s in "${SLUGS[@]}"; do echo "<th>${GLYPH[$s]}<br>${NAME[$s]}</th>"; done)</tr></thead>
    <tbody>
${GRID_ROWS}
    </tbody>
  </table>
  </div>

$(ad_block "🔮" "Patrocina trafico SEO de alta intencion" "Tu marca puede aparecer entre la herramienta de calculo y las 144 combinaciones de signos." "Ver media kit ->")

  <div class="cta-box">
    <h3>🔮 ¿Quieres ir más allá del signo solar?</h3>
    <p>La verdadera compatibilidad depende de tu carta natal completa: Luna, Venus, Marte, ascendente y más.</p>
    <a href="https://carta-astral-gratis.es/">Calcular carta astral gratis →</a>
  </div>

  <div class="seo-text panel">
    <h2>¿Cómo funciona la compatibilidad entre signos?</h2>
    <p>La compatibilidad astrológica analiza la relación entre dos signos del zodíaco basándose en tres factores clave:</p>
    <ul>
      <li><strong>Elemento:</strong> Los 12 signos se dividen en Fuego (Aries, Leo, Sagitario), Tierra (Tauro, Virgo, Capricornio), Aire (Géminis, Libra, Acuario) y Agua (Cáncer, Escorpio, Piscis). Los elementos del mismo grupo se entienden naturalmente.</li>
      <li><strong>Modalidad:</strong> Cardinal (iniciadores), Fijo (estables) y Mutable (adaptables). La interacción entre modalidades afecta al ritmo de la relación.</li>
      <li><strong>Planeta regente:</strong> Cada signo está gobernado por un planeta que marca su esencia. La interacción entre regentes planetarios añade la capa más profunda al análisis.</li>
    </ul>

    <h2>¿Qué signos son más compatibles?</h2>
    <p>Las combinaciones con mayor afinidad natural son entre signos del mismo elemento o elementos complementarios:</p>
    <ul>
      <li><strong>Fuego + Aire:</strong> Pasión, dinamismo y aventura. Aries con Géminis, Leo con Libra, Sagitario con Acuario.</li>
      <li><strong>Tierra + Agua:</strong> Estabilidad, nutrición y profundidad. Tauro con Cáncer, Virgo con Escorpio, Capricornio con Piscis.</li>
      <li><strong>Mismo elemento:</strong> Comprensión intuitiva y valores compartidos.</li>
    </ul>

    <h2>¿La compatibilidad de signos determina una relación?</h2>
    <p>El signo solar es solo una parte de tu carta astral. La verdadera compatibilidad amorosa depende de la interacción entre las cartas natales completas de ambas personas: la posición de Venus (cómo amas), Marte (cómo deseas), la Luna (tus emociones) y el ascendente (cómo te perciben). Nuestra herramienta gratuita de <a href="https://carta-astral-gratis.es/">carta astral</a> te permite calcular todos estos factores.</p>
  </div>

$(cluster_recirculation_block "$SITE_KEY")

$(gen_footer)
</div>
<script>
function openCompatibilityFromHome(){
  const s1=document.getElementById('s1').value;
  const s2=document.getElementById('s2').value;
  const target='/' + s1 + '-' + s2;
  if(window.clusterTrack){
    window.clusterTrack('compatibility_view',{
      selected_sign_1:s1,
      selected_sign_2:s2,
      target_path:target
    });
  }
  setTimeout(()=>{ location.href=target; },80);
}
</script>
</body>
</html>
ENDINDEX

SITEMAP_URLS="  <url><loc>https://${DOMAIN}/</loc><lastmod>${TODAY}</lastmod><changefreq>weekly</changefreq><priority>1.0</priority></url>\n${SITEMAP_URLS}"
echo "  ✓ index.html"

# ══════════════════════════════════════════════════════════════
# STATIC FILES: 404, ads.txt, robots.txt, sitemap.xml
# ══════════════════════════════════════════════════════════════

# ads.txt
echo "google.com, ${ADSENSE_PUB#ca-}, DIRECT, f08c47fec0942fa0" > "$PUBLIC/ads.txt"

# publicidad
gen_publicidad_page "$SITE_KEY" "$PUBLIC"

# robots.txt
cat > "$PUBLIC/robots.txt" <<ENDROBOTS
User-agent: *
Allow: /
Sitemap: https://${DOMAIN}/sitemap.xml
ENDROBOTS

# sitemap.xml
SITEMAP_URLS+="  <url><loc>https://${DOMAIN}/publicidad</loc><lastmod>${TODAY}</lastmod><changefreq>monthly</changefreq><priority>0.6</priority></url>\n"
cat > "$PUBLIC/sitemap.xml" <<ENDSITEMAP
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
$(echo -e "$SITEMAP_URLS")</urlset>
ENDSITEMAP

# 404
cat > "$PUBLIC/404.html" <<END404
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Página no encontrada — Compatibilidad Signos</title>
  <meta name="robots" content="noindex">
  <style>${COMMON_CSS}</style>
</head>
<body>
<div class="container" style="text-align:center;padding:4rem 1rem">
  <div style="font-size:4rem">♈♏</div>
  <h1>Página no encontrada</h1>
  <p style="color:var(--muted);margin:1rem 0">Los astros no encuentran esta ruta. Vuelve al inicio para explorar compatibilidades.</p>
  <a href="/" style="display:inline-block;padding:.6rem 1.5rem;background:var(--accent);color:#fff;border-radius:10px;text-decoration:none;font-weight:600">← Volver al inicio</a>
</div>
</body>
</html>
END404

echo "  ✓ ads.txt, robots.txt, sitemap.xml, 404.html"
bash "$REPO_ROOT/gen-legal.sh" "$SITE_KEY"
echo "Done! ${PAGE_COUNT} pages + index + static files in $PUBLIC"
