# Astro Cluster Gmail

Utilidad aislada para enviar correo del cluster desde `publicidad@carta-astral-gratis.es`
usando la misma estrategia operativa que LicitaGo: Gmail SMTP con `GMAIL_USER` y
`GMAIL_PASS`.

## Prueba local SMTP

```bash
GMAIL_USER="..." \
GMAIL_PASS="..." \
ASTRO_MAIL_TO="publicidad@carta-astral-gratis.es" \
npm run smoke:smtp --prefix functions-gmail
```

La prueba envía un correo a `ASTRO_MAIL_TO`. Para validar recepción de punta a
punta, el destinatario recomendado es el propio alias
`publicidad@carta-astral-gratis.es`.

Para consultar automaticamente la recepcion por IMAP:

```bash
GMAIL_USER="..." \
GMAIL_PASS="..." \
ASTRO_MAIL_TO="info@licitago.es" \
ASTRO_MAIL_SUBJECT="asunto exacto enviado" \
npm run smoke:imap --prefix functions-gmail
```

## Alias Workspace

Si existe delegación de todo el dominio para una service account de Workspace,
el alias y la identidad de envío se pueden revisar o crear así:

Scopes necesarios en Google Admin para esa service account:

```text
https://www.googleapis.com/auth/admin.directory.user,https://www.googleapis.com/auth/admin.directory.user.readonly,https://www.googleapis.com/auth/admin.directory.user.alias,https://www.googleapis.com/auth/admin.directory.group,https://www.googleapis.com/auth/admin.directory.group.readonly,https://www.googleapis.com/auth/admin.directory.group.member,https://www.googleapis.com/auth/gmail.settings.basic,https://www.googleapis.com/auth/gmail.settings.sharing,https://www.googleapis.com/auth/gmail.readonly,https://www.googleapis.com/auth/gmail.send
```

```bash
GOOGLE_APPLICATION_CREDENTIALS="/ruta/service-account-workspace.json" \
WORKSPACE_ADMIN_IMPERSONATE="info@licitago.es" \
WORKSPACE_TARGET_USER="publicidad@licitago.es" \
node functions-gmail/scripts/workspace-alias.js inspect

GOOGLE_APPLICATION_CREDENTIALS="/ruta/service-account-workspace.json" \
WORKSPACE_ADMIN_IMPERSONATE="info@licitago.es" \
WORKSPACE_TARGET_USER="publicidad@licitago.es" \
node functions-gmail/scripts/workspace-alias.js ensure
```

`ensure` crea `publicidad@carta-astral-gratis.es` como alias de
`WORKSPACE_TARGET_USER` y lo registra como `sendAs` de Gmail si todavía no
existen. Si el dominio está añadido como alias de dominio, puede aparecer como
alias no editable del usuario destino; en ese caso `ensure` lo respeta y solo
crea la identidad de envío.

Para operar con una sola licencia, el usuario destino debe ser
`info@licitago.es`. Si existe un usuario separado `publicidad@licitago.es`, el
alias de dominio `publicidad@carta-astral-gratis.es` queda capturado por ese
usuario y no por `info@licitago.es`. En ese caso hay que eliminar primero el
usuario separado, esperar a que libere el alias y ejecutar:

```bash
GOOGLE_APPLICATION_CREDENTIALS="/ruta/service-account-workspace.json" \
WORKSPACE_ADMIN_IMPERSONATE="info@licitago.es" \
WORKSPACE_TARGET_USER="info@licitago.es" \
WORKSPACE_GROUP_EMAIL="publicidad@licitago.es" \
WORKSPACE_GROUP_MEMBER="info@licitago.es" \
node functions-gmail/scripts/workspace-alias.js ensure-group
```

Después se puede crear la identidad de envío en el buzón único:

```bash
GOOGLE_APPLICATION_CREDENTIALS="/ruta/service-account-workspace.json" \
WORKSPACE_ADMIN_IMPERSONATE="info@licitago.es" \
WORKSPACE_TARGET_USER="info@licitago.es" \
WORKSPACE_GMAIL_IMPERSONATE="info@licitago.es" \
node functions-gmail/scripts/workspace-alias.js ensure
```

## Pruebas Gmail API

```bash
GOOGLE_APPLICATION_CREDENTIALS="/ruta/service-account-workspace.json" \
WORKSPACE_GMAIL_IMPERSONATE="info@licitago.es" \
GMAIL_QUERY="to:publicidad@carta-astral-gratis.es newer_than:1d" \
npm run probe:list --prefix functions-gmail

GOOGLE_APPLICATION_CREDENTIALS="/ruta/service-account-workspace.json" \
WORKSPACE_GMAIL_IMPERSONATE="info@licitago.es" \
ASTRO_MAIL_TO="poorku@gmail.com" \
npm run probe:send --prefix functions-gmail
```

`publicidad@carta-astral-gratis.es` es un alias comercial. Para mantener una
sola licencia Workspace, las pruebas y los workflows deben impersonar
`info@licitago.es` y usar el alias solo como `From`/`Reply-To`, siempre que
aparezca en `settings/sendAs` de Gmail.

## Cloud Function

La función `sendAstroClusterEmail` queda preparada para desplegarse con secretos
Firebase:

- `GMAIL_USER`
- `GMAIL_PASS`
- `ASTRO_GMAIL_API_KEY`

El endpoint exige `POST`, origen de uno de los dominios del cluster y cabecera
`x-astro-mail-key`.
