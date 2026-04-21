# Advertising outreach playbook

Objetivo: captar anunciantes directos para los banners del cluster mientras AdSense queda como remanente cuando se apruebe.

## Cadencia

- Prospeccion: lunes a jueves por la tarde, hasta 10 candidatos nuevos por ejecucion.
- Envio: lunes a jueves por la manana, maximo 2 correos por ejecucion.
- El cron de envio arranca en `dry-run`; para activar envio programado real hay que definir la variable de repositorio `AD_OUTREACH_SCHEDULE_SEND=1`.
- El envio real tambien puede lanzarse manualmente con `workflow_dispatch` y `mode=send`.
- Primer mes: mantener el limite en 2/dia y dejar que el sistema apruebe solo candidatos con validacion tecnica fuerte.
- Sin follow-ups automaticos hasta tener respuestas reales y tasa de rebote estable.

## Reglas de aprobacion

- Enviar solo a contactos profesionales publicados en la web de origen.
- Exigir MX valido y email visible en la fuente publica.
- Autoaprobar candidatos nuevos solo si pasan MX, URL publica valida, email visible en fuente publica y validacion fresca.
- `approved_by: automation` es aceptable cuando la validacion tecnica es fuerte; la revision humana queda para casos excepcionales.
- Los buzones personales como Gmail, Hotmail, Outlook o Yahoo solo son aceptables si estan publicados en la fuente publica del negocio.
- No reenviar a un prospecto con `sent_at`, `suppressed_at`, `bounced` o `not_interested`.
- No enviar nunca dos emails de captacion al mismo email normalizado, aunque aparezca duplicado como otro prospect.

## Buzon

- `publicidad@carta-astral-gratis.es` es un alias comercial.
- La cuenta delegada de Gmail debe ser `info@licitago.es`.
- Transporte preferente: Gmail API con Domain-Wide Delegation de la service account del Workspace.
- Transporte de contingencia: SMTP/IMAP con `GMAIL_USER` y `GMAIL_PASS`, solo si se fuerza `AD_OUTREACH_MAIL_TRANSPORT=smtp`.
- Antes de enviar, el workflow comprueba que el alias existe como identidad `sendAs` en `info@licitago.es`.
- El `From` y el `Reply-To` comerciales se mantienen como `publicidad@carta-astral-gratis.es`.
- Guia de autorizacion DWD: `docs/AD_OUTREACH_DWD.md`.

## Umbrales operativos

- Rebote mayor de 5%: pausar envios y revisar fuentes.
- No interes mayor de 10%: reducir volumen y ajustar segmento/copy.
- Respuestas positivas: priorizar ese segmento en las queries y preparar propuesta comercial manual.

## FinOps

- Sin servicios de email marketing de pago.
- Sin artifacts ni caches en GitHub Actions.
- Uso de `ubuntu-latest` y jobs cortos con `timeout-minutes: 10`.
- Google Programmable Search se limita con `MAX_SEARCH_QUERIES` y `MAX_RESULTS_PER_QUERY`.
