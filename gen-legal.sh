#!/usr/bin/env bash
set -euo pipefail
# Generate privacy.html + terms.html for one or more cluster sites (AdSense requirement)

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
source "$REPO_ROOT/shared/config.sh"

TODAY_DISPLAY="9 de abril de 2026"

# Site-specific descriptions
declare -A SITE_DESC=(
  [compatibilidad-signos]="cálculo de compatibilidad entre signos del zodíaco"
  [tarot-del-dia]="tirada de tarot gratuita con los Arcanos Mayores"
  [calcular-numerologia]="cálculo de numerología (número de vida)"
  [horoscopo-de-hoy]="predicciones de horóscopo diario para los 12 signos"
)

declare -A SITE_DATA_COLLECTED=(
  [compatibilidad-signos]="No recopilamos datos personales. La herramienta no requiere registro ni introducción de información personal. Solo seleccionas dos signos del zodíaco."
  [tarot-del-dia]="No recopilamos datos personales. La tirada de tarot es completamente anónima y se ejecuta en tu navegador. No se envía información al servidor."
  [calcular-numerologia]="Para calcular tu número de vida, introduces tu fecha de nacimiento. Este dato se procesa íntegramente en tu navegador (JavaScript) y nunca se envía a nuestros servidores."
  [horoscopo-de-hoy]="No recopilamos datos personales. El horóscopo se genera de forma estática y se muestra igual para todos los visitantes del mismo signo."
)

declare -A SITE_SERVICE_DESC=(
  [compatibilidad-signos]="un servicio gratuito de análisis de compatibilidad astrológica entre signos del zodíaco. Analiza la afinidad basándose en elementos, modalidades y planetas regentes."
  [tarot-del-dia]="un servicio gratuito de tirada de tarot con los 22 Arcanos Mayores. Las cartas se seleccionan aleatoriamente en tu navegador."
  [calcular-numerologia]="un servicio gratuito de numerología que calcula tu número de vida a partir de tu fecha de nacimiento. Usa el método pitagórico de reducción a un dígito."
  [horoscopo-de-hoy]="un servicio gratuito de horóscopo diario para los 12 signos del zodíaco. Las predicciones se actualizan cada día."
)

CSS='
    :root{--bg:#faf8f5;--surface:#fff;--border:#e8e0d8;--text:#2d2a26;--muted:#7a7268;--accent:#7c3aed}
    *{margin:0;padding:0;box-sizing:border-box}
    body{font-family:"Inter",system-ui,sans-serif;background:var(--bg);color:var(--text);min-height:100vh}
    .wrap{max-width:780px;margin:0 auto;padding:2rem 1.5rem}
    .logo{text-align:center;font-size:.85rem;letter-spacing:.15em;text-transform:uppercase;color:var(--accent);font-weight:600;margin-bottom:.5rem}
    h1{font-family:"Playfair Display",Georgia,serif;font-size:2rem;text-align:center;margin-bottom:2rem}
    h2{font-family:"Playfair Display",Georgia,serif;font-size:1.2rem;margin:1.5rem 0 .5rem;color:var(--text)}
    p,li{line-height:1.75;color:var(--muted);font-size:.9rem;margin-bottom:.6rem}
    ul{padding-left:1.3rem;margin-bottom:1rem}
    a{color:var(--accent);text-decoration:none}
    a:hover{text-decoration:underline}
    .panel{background:var(--surface);border:1px solid var(--border);border-radius:16px;padding:2rem;box-shadow:0 2px 12px rgba(124,58,237,.08);margin-bottom:1.5rem}
    .back{display:inline-block;margin-bottom:1.5rem;font-size:.85rem;color:var(--accent)}
    footer{text-align:center;padding:2rem 1rem;font-size:.75rem;color:var(--muted);border-top:1px solid var(--border);margin-top:2rem}
    .updated{text-align:center;font-size:.8rem;color:var(--muted);margin-bottom:1.5rem}
    .network{text-align:center;font-size:.75rem;color:var(--muted);margin-top:1rem}
    .network a{color:var(--accent);text-decoration:none}
'

if [[ $# -gt 0 ]]; then
  SITE_KEYS=("$@")
else
  SITE_KEYS=(compatibilidad-signos tarot-del-dia calcular-numerologia horoscopo-de-hoy)
fi

for site_key in "${SITE_KEYS[@]}"; do
  if [[ -z "${DOMAINS[$site_key]:-}" ]]; then
    echo "Unknown site key: ${site_key}" >&2
    exit 1
  fi
  if [[ -z "${SITE_DESC[$site_key]:-}" ]]; then
    echo "No legal template configured for site: ${site_key}" >&2
    exit 1
  fi
  domain="${DOMAINS[$site_key]}"
  site_name="${CROSSLINKS[$site_key]}"
  desc="${SITE_DESC[$site_key]}"
  data="${SITE_DATA_COLLECTED[$site_key]}"
  svc="${SITE_SERVICE_DESC[$site_key]}"
  crosslinks=$(crosslink_footer "$site_key")
  public="${REPO_ROOT}/sites/${site_key}/public"

  # ── privacy.html ──────────────────────────────────────────
  cat > "$public/privacy.html" <<ENDPRIV
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Política de Privacidad — ${site_name}</title>
  <meta name="description" content="Política de privacidad de ${domain}. Información sobre cookies, Google Analytics y AdSense.">
  <link rel="canonical" href="https://${domain}/privacy">
  <meta name="robots" content="noindex, follow">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="${BRAND_FONTS}" rel="stylesheet">
$(canonical_host_redirect_script "$domain")
  <style>${CSS}</style>
</head>
<body>
<div class="wrap">
  <a href="/" class="back">← Volver a ${site_name}</a>
  <div class="logo">✦ ${site_name} ✦</div>
  <h1>Política de Privacidad</h1>
  <p class="updated">Última actualización: ${TODAY_DISPLAY}</p>

  <div class="panel">
    <h2>1. Responsable del tratamiento</h2>
    <p>El sitio web <strong>${domain}</strong> es un servicio gratuito de ${desc}.
    Contacto: <a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a></p>

    <h2>2. Datos que recopilamos</h2>
    <p>${data}</p>

    <h2>3. Cookies y tecnologías de seguimiento</h2>
    <p>Utilizamos las siguientes tecnologías:</p>
    <ul>
      <li><strong>Google Analytics 4 (GA4)</strong> — para analizar el tráfico web de forma anónima. <a href="https://policies.google.com/privacy" target="_blank" rel="noopener">Política de privacidad de Google</a>.</li>
      <li><strong>Google AdSense</strong> — para mostrar anuncios. Publisher: ${ADSENSE_PUB}. Puedes gestionar tus preferencias en <a href="https://adssettings.google.com/" target="_blank" rel="noopener">adssettings.google.com</a>.</li>
    </ul>
    <p>Puedes desactivar las cookies en cualquier momento desde la configuración de tu navegador.</p>

    <h2>4. Base legal del tratamiento</h2>
    <ul>
      <li><strong>Consentimiento</strong> (Art. 6.1.a RGPD) — para cookies analíticas y publicitarias.</li>
      <li><strong>Interés legítimo</strong> (Art. 6.1.f RGPD) — para el funcionamiento del servicio.</li>
    </ul>

    <h2>5. Transferencias internacionales</h2>
    <p>Los datos analíticos se procesan por Google LLC (EE.UU.) bajo las cláusulas contractuales tipo aprobadas por la Comisión Europea.</p>

    <h2>6. Periodo de conservación</h2>
    <p>Las cookies de GA4 expiran a los 14 meses. Las cookies de AdSense según la configuración de Google.</p>

    <h2>7. Tus derechos</h2>
    <p>Conforme al RGPD y la LOPDGDD, tienes derecho a acceso, rectificación, supresión, portabilidad, oposición y limitación del tratamiento.</p>
    <p>Contacto: <a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a></p>
    <p>También puedes presentar una reclamación ante la <a href="https://www.aepd.es/" target="_blank" rel="noopener">Agencia Española de Protección de Datos (AEPD)</a>.</p>

    <h2>8. Seguridad</h2>
    <p>El sitio utiliza HTTPS (TLS 1.3) a través de Firebase Hosting.</p>

    <h2>9. Menores</h2>
    <p>Este servicio no está dirigido a menores de 14 años.</p>

    <h2>10. Cambios en esta política</h2>
    <p>Nos reservamos el derecho a actualizar esta política. La fecha de última actualización aparece al principio del documento.</p>
  </div>
</div>
<footer>
  <p>© $(date +%Y) ${site_name} · <a href="/privacy">Privacidad</a> · <a href="/terms">Términos</a> · <a href="/">Inicio</a></p>
  ${crosslinks}
</footer>
</body>
</html>
ENDPRIV

  # ── terms.html ────────────────────────────────────────────
  cat > "$public/terms.html" <<ENDTERMS
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Términos de Uso — ${site_name}</title>
  <meta name="description" content="Términos y condiciones de uso de ${domain}. Servicio gratuito de ${desc}.">
  <link rel="canonical" href="https://${domain}/terms">
  <meta name="robots" content="noindex, follow">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="${BRAND_FONTS}" rel="stylesheet">
$(canonical_host_redirect_script "$domain")
  <style>${CSS}</style>
</head>
<body>
<div class="wrap">
  <a href="/" class="back">← Volver a ${site_name}</a>
  <div class="logo">✦ ${site_name} ✦</div>
  <h1>Términos de Uso</h1>
  <p class="updated">Última actualización: ${TODAY_DISPLAY}</p>

  <div class="panel">
    <h2>1. Descripción del servicio</h2>
    <p><strong>${site_name}</strong> (${domain}) es ${svc}</p>

    <h2>2. Naturaleza del contenido</h2>
    <p>Los resultados proporcionados son de <strong>carácter informativo y de entretenimiento</strong>. La astrología, el tarot y la numerología son herramientas de autoconocimiento basadas en tradiciones milenarias, no servicios médicos, psicológicos, financieros ni legales.</p>
    <p>No nos hacemos responsables de decisiones tomadas en base a los resultados ofrecidos.</p>

    <h2>3. Uso aceptable</h2>
    <p>Al utilizar este servicio, te comprometes a:</p>
    <ul>
      <li>No utilizar el servicio para fines ilegales o fraudulentos.</li>
      <li>No intentar sobrecargar o atacar la infraestructura del sitio.</li>
      <li>No realizar scraping masivo del servicio ni de sus resultados.</li>
    </ul>

    <h2>4. Propiedad intelectual</h2>
    <p>El diseño, código y contenido de ${domain} son propiedad de sus creadores. Los resultados generados para ti son de tu uso libre.</p>

    <h2>5. Disponibilidad</h2>
    <p>El servicio se ofrece "tal cual" sin garantías de disponibilidad continua. Nos reservamos el derecho de interrumpir o modificar el servicio en cualquier momento.</p>

    <h2>6. Publicidad</h2>
    <p>El sitio se financia mediante publicidad proporcionada por Google AdSense. Los anuncios se muestran de acuerdo con las preferencias del usuario y las políticas de Google.</p>

    <h2>7. Limitación de responsabilidad</h2>
    <p>No nos hacemos responsables de pérdidas o daños derivados del uso del servicio o de la interpretación de sus resultados.</p>

    <h2>8. Legislación aplicable</h2>
    <p>Estos términos se rigen por la legislación española. Para cualquier controversia, las partes se someten a los juzgados y tribunales de Madrid.</p>

    <h2>9. Contacto</h2>
    <p>Para consultas: <a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a></p>
  </div>
</div>
<footer>
  <p>© $(date +%Y) ${site_name} · <a href="/privacy">Privacidad</a> · <a href="/terms">Términos</a> · <a href="/">Inicio</a></p>
  ${crosslinks}
</footer>
</body>
</html>
ENDTERMS

  echo "  ✓ ${site_key}: privacy.html + terms.html"
done

echo "Done! Legal pages generated for: ${SITE_KEYS[*]}"
