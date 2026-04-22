# Guía de captación publicitaria

Objetivo: captar anunciantes directos para los banners del cluster mientras AdSense queda como remanente cuando se apruebe.

## Cadencia

- Prospección: lunes a jueves por la tarde, hasta 10 candidatos nuevos por ejecución.
- Envío: lunes a jueves por la mañana, máximo 2 correos por ejecución. Hora elegida: 08:20 UTC, que cae en horario laboral de España peninsular todo el año.
- Antes de escoger destinatarios nuevos, el workflow consulta el buzón y sincroniza respuestas, rebotes y bajas.
- Cuando una conversación queda tratada (respuesta, baja o rebote), se archiva y se marca como leída automáticamente para limpiar la bandeja de entrada.
- El cron de envío arranca en `dry-run`; para activar envío programado real hay que definir la variable de repositorio `AD_OUTREACH_SCHEDULE_SEND=1`.
- El envío real también puede lanzarse manualmente con `workflow_dispatch` y `mode=send`.
- Primer mes: mantener el límite en 2/día y dejar que el sistema apruebe solo candidatos con validación técnica fuerte.
- Sin seguimientos automáticos hasta tener respuestas reales y tasa de rebote estable.
- Guardarraíl de volumen: aunque alguien suba `AD_OUTREACH_MAX_SEND`, `AD_OUTREACH_HARD_MAX_SEND=2` mantiene el techo operativo.
- Guardarraíl comercial: si hay respuestas positivas abiertas sin `commercial_followup_at` ni `closed_at`, se pausa el envío nuevo hasta atenderlas.
- Rebote aislado: no pausa toda la captación; se suprime el contacto rebotado, se enfría temporalmente su segmento y se priorizan candidatos con mayor evidencia pública.
- Para reanudar tras una respuesta positiva, anotar en el prospecto `commercial_followup_at` cuando se haya contestado con propuesta comercial, o `closed_at` si la oportunidad queda descartada.

## Reglas de aprobación

- Enviar solo a contactos profesionales publicados en la web de origen.
- Exigir MX válido y email visible en la fuente pública.
- Autoaprobar candidatos nuevos solo si pasan MX, URL pública válida, email visible en fuente pública y validación fresca.
- Registrar señales de confianza (`validation_score`, `validation_confidence`, `validation_signals`) para priorizar contactos con `mailto`, dominio de fuente alineado y buzón comercial publicado.
- `approved_by: automation` es aceptable cuando la validación técnica es fuerte; la revisión humana queda para casos excepcionales.
- Los buzones personales como Gmail, Hotmail, Outlook o Yahoo solo son aceptables si están publicados en la fuente pública del negocio.
- No reenviar a un prospecto con `sent_at`, `suppressed_at`, `bounced` o `not_interested`.
- No enviar nunca dos emails de captación al mismo email normalizado, aunque aparezca duplicado como otro candidato.

## Buzón

- `publicidad@carta-astral-gratis.es` es un alias comercial.
- La cuenta delegada de Gmail debe ser `info@licitago.es`.
- Transporte preferente: Gmail API con Domain-Wide Delegation de la service account del Workspace.
- Transporte de contingencia: SMTP/IMAP con `GMAIL_USER` y `GMAIL_PASS`, solo si se fuerza `AD_OUTREACH_MAIL_TRANSPORT=smtp`.
- Antes de enviar, el workflow comprueba que el alias existe como identidad `sendAs` en `info@licitago.es`.
- El `From` y el `Reply-To` comerciales se mantienen como `publicidad@carta-astral-gratis.es`.
- Guía de autorización DWD: `docs/AD_OUTREACH_DWD.md`.

## Umbrales operativos

- Rebote mayor de 5% con al menos 10 envíos históricos: pausar envíos y revisar fuentes.
- No interés mayor de 10% con al menos 10 envíos históricos: reducir volumen y ajustar segmento/copy.
- Respuestas positivas: priorizar ese segmento en las queries y preparar propuesta comercial manual.

## FinOps

- Sin servicios de email marketing de pago.
- Sin artifacts ni caches en GitHub Actions.
- Uso de `ubuntu-latest` y jobs cortos con `timeout-minutes: 10`.
- Google Programmable Search se limita con `MAX_SEARCH_QUERIES` y `MAX_RESULTS_PER_QUERY`.
