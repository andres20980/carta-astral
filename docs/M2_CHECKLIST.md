# M2 Checklist

Checklist operativo para decidir si el cluster esta listo para empujar M2 sin gastar mas de lo necesario.

## Indexacion

- [ ] GSC no muestra nuevos motivos de exclusion para URLs criticas.
- [ ] `calcular-numerologia.es` no tiene URLs indexables con `noindex`.
- [ ] Sitemaps frescos y con canonical correcto.
- [ ] Homes con title, description, H1, canonical y JSON-LD.

## Operacion

- [ ] Deploy de sitios modificados en verde.
- [ ] SEO smoke en verde o con issue abierto y accionable.
- [ ] Lighthouse solo ejecutado manualmente cuando haga falta.
- [ ] Acciones semanales sin pico anormal de runs.

## Monetizacion

- [ ] `ads.txt` correcto en dominio raiz y `www`.
- [ ] `/publicidad` accesible, indexable y enlazada.
- [ ] Evento `advertiser_cta_click` visible en GA4.
- [ ] Lista corta de prospects preparada antes de activar nuevo outreach.

## Decision

- [ ] Si indexacion y operacion estan en verde, pasar a crecimiento/contenido.
- [ ] Si hay warning GSC activo, inspeccionar URL manualmente antes de tocar generadores.
- [ ] Si hay costes/CI al alza, reducir cron antes de anadir nuevos checks.
