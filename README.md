# Astro Cluster

Cluster de sitios estáticos SEO en español sobre astrología, tarot, numerología y horóscopo, desplegados en Firebase Hosting.

## Sitios

| Site key | Dominio | Firebase project |
|---|---|---|
| `carta-astral` | `carta-astral-gratis.es` | `carta-astral-f4ab9` |
| `compatibilidad-signos` | `compatibilidad-signos.es` | `compat-signos-es` |
| `tarot-del-dia` | `tarot-del-dia.es` | `tarot-del-dia-es` |
| `calcular-numerologia` | `calcular-numerologia.es` | `calc-numerologia-es` |
| `horoscopo-de-hoy` | `horoscopo-de-hoy.es` | `horoscopo-hoy-es` |

## Qué hay en el repo

- `sites/*/scripts/gen-pages.sh`: genera HTML estático, `ads.txt`, `robots.txt`, `sitemap.xml` y páginas legales.
- `sites/*/public/`: salida estática lista para deploy.
- `shared/config.sh`: configuración compartida de dominios, GA4, AdSense, crosslinks y media kits.
- `shared/ga4_custom_dimensions.json` y `shared/ga4_key_events.json`: estado deseado de la configuración GA4 Admin.
- `scripts/`: utilidades compartidas del repo que no pertenecen a un único site.
- `docs/`: documentación y estado operativo global del cluster.
- `sites/*/docs/`: señales SEO y estado operativo específico de cada site.
- `deploy.sh`: deploy manual a Firebase Hosting.
- `.github/workflows/`: automatización de deploy, smoke SEO, daily regen y reporting.

## Monetización

- Publisher AdSense compartido: `ca-pub-9368517395014039`
- Measurement ID GA4 compartido para todo el cluster: `G-DEWMQ73FH5`
- Todos los sitios publican `ads.txt` con ese publisher.
- Todas las variantes `www` sirven `ads.txt` por HTTPS para no romper validaciones de AdSense.
- El script de Auto Ads está preparado como opt-in: generar con `ADSENSE_AUTO_ADS_ENABLED=1` o definir la variable de GitHub Actions `ADSENSE_AUTO_ADS_ENABLED=1` lo inserta cuando AdSense marque los sitios como listos.
- Todos los sitios incluyen huecos premium y landing `/publicidad` para venta directa.
- La venta directa convive con AdSense y tiene prioridad comercial sobre inventario remanente.
- El tracking GA4 se hace con linker cross-domain para mantener la sesión al saltar entre herramientas.

## Search Console

- Las 5 propiedades de dominio del cluster están verificadas en GSC.
- El deploy envía `sitemap.xml` a Search Console por API autenticada.
- El cluster se gestiona por dominio en GSC y de forma unificada en Analytics.
- `sites/carta-astral/scripts/manage-google.sh` ya admite `--site <site-key|dominio>` y operaciones GSC para todo el cluster.

## OAuth de Google

- Los workflows del cluster reutilizan `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET` y `GOOGLE_OAUTH_REFRESH_TOKEN`.
- Para GSC, el refresh token debe incluir `https://www.googleapis.com/auth/webmasters` y `https://www.googleapis.com/auth/siteverification`.
- Para AdSense, ese mismo refresh token debe incluir además `https://www.googleapis.com/auth/adsense.readonly`.
- Para Admin API de Analytics, ese mismo refresh token debe incluir `https://www.googleapis.com/auth/analytics.edit`.
- Para depuración manual de Analytics vía OAuth, `https://www.googleapis.com/auth/analytics.readonly` es opcional; para sincronizar custom dimensions y key events basta `analytics.edit`.
- Si el refresh token no tiene esos scopes, los workflows seguirán generando issues canónicos explicando el bloqueo exacto.

## Desarrollo local

Generar un sitio:

```bash
bash sites/compatibilidad-signos/scripts/gen-pages.sh
```

Desplegar un sitio:

```bash
./deploy.sh compatibilidad-signos
```

Desplegar todos:

```bash
./deploy.sh
```

## Estructura

```text
astro-cluster/
├── .github/
│   ├── scripts/
│   └── workflows/
├── docs/
│   ├── AD_*.md/json/txt
│   ├── DNS.md
│   └── GROWTH_MILESTONES.json
├── scripts/
│   └── generate-legal-pages.sh
├── shared/
│   └── config.sh
├── sites/
│   ├── carta-astral/
│   ├── compatibilidad-signos/
│   ├── tarot-del-dia/
│   ├── calcular-numerologia/
│   └── horoscopo-de-hoy/
└── deploy.sh
```

## Convenciones de organización

- Estado global del negocio, DNS, outreach y milestones: `docs/`.
- Estado SEO generado por site: `sites/<site-key>/docs/`.
- No usar carpetas anidadas tipo `sites/<site-key>/docs/docs`; si un archivo aplica a un solo site, va directamente en `sites/<site-key>/docs/`.
- Scripts de un site concreto: `sites/<site-key>/scripts/`.
- Scripts compartidos de generación/mantenimiento: `scripts/`.
- Configuración compartida consumida por varios sites o workflows: `shared/`.
- Workflows con kebab-case (`seo-auto-pr.yml`) y scripts Python con snake_case (`weekly_gsc_report.py`). Los scripts JavaScript existentes mantienen kebab-case por compatibilidad con workflows.

## Automatización

- `deploy-all-sites.yml`: despliega solo los sitios afectados por cambios reales en `sites/*` o `shared/`, y tras cada deploy envía el sitemap a GSC con la API oficial.
- `seo-smoke-all.yml`: comprueba `robots.txt`, `sitemap.xml`, `ads.txt`, páginas legales, `/publicidad`, canonical, meta description, `H1`, structured data, `noindex`, script AdSense y accesibilidad de `www`.
- `daily-horoscope.yml`: regenera y publica `horoscopo-de-hoy`.
- `seo-auto-pr.yml`: aplica mejoras SEO automáticas sobre un site del cluster por ejecución y prioriza intents validados por competitor intel y señales GSC (CTR bajo con impresiones relevantes).
- El auto-SEO ignora señales de GSC/competencia envejecidas para no optimizar con datos stale.
- La selección automática del site a optimizar usa GSC + GA4 cuando hay señal fresca; si no, vuelve al fallback rotatorio.
- En los sites generados, el auto-SEO actualiza tanto la home como las plantillas de sus familias long-tail para propagar mejoras a muchas URLs con un único cambio barato.
- El weekly report genera señales por familia de plantillas para que el auto-SEO priorice también dónde tocar dentro de cada site.
- `seo-competitor-intel.yml`: captura señales de competidores de forma rotatoria para un site del cluster por ejecución, con guardia de recencia para evitar gasto innecesario en GitHub Actions.
- `weekly-google-report.yml`: genera informe con GA4, GSC y AdSense, con bloque agregado del cluster y detalle por dominio.
- `ga4-admin-sync.yml`: sincroniza mensualmente o bajo demanda las custom dimensions y key events de GA4 contra los manifiestos del repo.
- `gsc-index-watch.yml`: mantiene un issue canónico con el estado de indexación de las home del cluster.
- `adsense-site-watch.yml`: mantiene un issue canónico con el estado de los sitios del cluster en la API de AdSense y sus alertas activas.
- `google-auth-audit.yml`: audita los scopes reales del OAuth del cluster y la salud del acceso a Analytics por service account.

## Principios operativos

- Sitios estáticos, sin backend persistente, para mantener coste bajo y despliegue simple.
- Workflows pensados para GitHub free tier: menos ejecuciones inútiles, checks compactos y despliegues selectivos.
- Shared config para mantener consistencia de tracking, cross-domain analytics, branding, crosslinking y monetización.

## DNS

La referencia operativa está en [docs/DNS.md](/home/asanchez/Code/github-andres20980/astro-cluster/docs/DNS.md).
