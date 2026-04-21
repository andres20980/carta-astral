# Gmail DWD for advertising outreach

Objetivo: operar el outreach diario desde GitHub Actions con Gmail API y Domain-Wide Delegation, sin app passwords y con scopes minimos para enviar, leer respuestas y comprobar la identidad `sendAs`.

## Service account

- Project: `licitago-spain`
- Service account: `licitago-workspace-adminsdk@licitago-spain.iam.gserviceaccount.com`
- OAuth client ID: `103499506294515431597`
- Usuario impersonado: `info@licitago.es`
- From/Reply-To comercial: `publicidad@carta-astral-gratis.es`

## Scopes diarios

Autorizar estos scopes en Google Admin Console:

```text
https://www.googleapis.com/auth/gmail.send,https://www.googleapis.com/auth/gmail.readonly,https://www.googleapis.com/auth/gmail.settings.basic
```

Ruta recomendada:

```text
Google Admin > Security > Access and data control > API controls > Domain-wide delegation > Add new
```

En `Client ID`, usar:

```text
103499506294515431597
```

En `OAuth scopes`, pegar la lista de scopes diarios.

## Scopes temporales de setup

Solo hacen falta si se quiere que `functions-gmail/scripts/workspace-alias.js ensure` cree o revise alias, grupos o identidades automaticamente:

```text
https://www.googleapis.com/auth/admin.directory.user,https://www.googleapis.com/auth/admin.directory.user.readonly,https://www.googleapis.com/auth/admin.directory.user.alias,https://www.googleapis.com/auth/admin.directory.group,https://www.googleapis.com/auth/admin.directory.group.readonly,https://www.googleapis.com/auth/admin.directory.group.member,https://www.googleapis.com/auth/gmail.settings.basic,https://www.googleapis.com/auth/gmail.settings.sharing,https://www.googleapis.com/auth/apps.groups.settings
```

Para operacion diaria no mantener los scopes de Admin si no son necesarios.

## GitHub Actions secrets

El workflow `.github/workflows/ad-outreach.yml` usa Gmail API por defecto. Requiere:

```text
WORKSPACE_SERVICE_ACCOUNT_JSON
WORKSPACE_GMAIL_IMPERSONATE=info@licitago.es
```

No guardar el JSON de credenciales en el repositorio.

`GMAIL_USER` y `GMAIL_PASS` quedan como contingencia para `AD_OUTREACH_MAIL_TRANSPORT=smtp`, no como ruta principal.

## Verificacion

Antes de activar envios reales:

```bash
GOOGLE_APPLICATION_CREDENTIALS="/ruta/serviceAccountKey.json" \
WORKSPACE_GMAIL_IMPERSONATE="info@licitago.es" \
python3 .github/scripts/ad_outreach.py --check-mailbox --report /tmp/ad-outreach-dwd.md
```

En local, la credencial Workspace esperada esta en:

```text
/home/asanchez/Code/github-andres20980/licitago/ops/entorno-programatico/workspace/licitago-workspace-adminsdk.json
```

La salida debe indicar:

```text
Transporte: gmail_api
From configurado como sendAs: si
```

Prueba de lectura sin enviar:

```bash
GOOGLE_APPLICATION_CREDENTIALS="/ruta/serviceAccountKey.json" \
WORKSPACE_GMAIL_IMPERSONATE="info@licitago.es" \
GMAIL_QUERY="to:publicidad@carta-astral-gratis.es newer_than:1d" \
npm run probe:list --prefix functions-gmail
```
