# DNS - Astro Cluster

Referencia de DNS para los dominios del cluster en Piensa Solutions.

Fuente operativa:
- configuración objetivo del repo
- snapshot manual de Piensa Solutions compartido en `log.txt`

Fecha de referencia: `2026-04-12`

## Nameservers

Todos los dominios usan:

- `ns97.piensasolutions.com`
- `ns98.piensasolutions.com`

## Registros comunes

| Tipo | Nombre | Valor | TTL |
|---|---|---|---|
| `A` | `@` | `199.36.158.100` | `3600` |
| `MX` | `@` | `10 mx1.improvmx.com` | `3600` |
| `MX` | `@` | `20 mx2.improvmx.com` | `3600` |
| `TXT` | `@` | `v=spf1 include:spf.improvmx.com ~all` | `3600` |

Notas:
- `199.36.158.100` es la IP global de Firebase Hosting.
- ImprovMX se usa para forwarding de correo.

## carta-astral-gratis.es

Firebase project: `carta-astral-f4ab9`

| Tipo | Nombre | Valor | TTL |
|---|---|---|---|
| `A` | `@` | `199.36.158.100` | `3600` |
| `CNAME` | `www` | `carta-astral-f4ab9.web.app` | `3600` |
| `MX` | `@` | `10 mx1.improvmx.com` | `3600` |
| `MX` | `@` | `20 mx2.improvmx.com` | `3600` |
| `TXT` | `@` | `v=spf1 include:spf.improvmx.com ~all` | `3600` |
| `TXT` | `@` | `google-site-verification=x02IbSeXH-i8nm_h0nEA_iFzvdSa6jdOoILtcyXFsa8` | `3600` |
| `TXT` | `_acme-challenge` | `RPkgsG_f6LmpdscQrkyvxKY4o1eHijCDbcoWnjgdr_s` | `3600` |

Estado documentado:
- DNS base configurado en Piensa
- Search Console verificado

## compatibilidad-signos.es

Firebase project: `compat-signos-es`

| Tipo | Nombre | Valor | TTL |
|---|---|---|---|
| `A` | `@` | `199.36.158.100` | `3600` |
| `CNAME` | `www` | `compat-signos-es.web.app` | `3600` |
| `MX` | `@` | `10 mx1.improvmx.com` | `3600` |
| `MX` | `@` | `20 mx2.improvmx.com` | `3600` |
| `TXT` | `@` | `v=spf1 include:spf.improvmx.com ~all` | `3600` |
| `TXT` | `@` | `hosting-site=compat-signos-es` | `3600` |
| `TXT` | `@` | `google-site-verification=YLLqhMQrT84LFCfa9WTqOtC5p4fhrzqJjP_VHNgqDqo` | `3600` |
| `TXT` | `_acme-challenge` | `ae0XwtyMP3f8cx_unWdHbb17KLvfvzPihaZOyyA33Uk` | `3600` |

Estado documentado:
- DNS base configurado en Piensa
- Search Console verificado

## tarot-del-dia.es

Firebase project: `tarot-del-dia-es`

| Tipo | Nombre | Valor | TTL |
|---|---|---|---|
| `A` | `@` | `199.36.158.100` | `3600` |
| `CNAME` | `www` | `tarot-del-dia-es.web.app` | `3600` |
| `MX` | `@` | `10 mx1.improvmx.com` | `3600` |
| `MX` | `@` | `20 mx2.improvmx.com` | `3600` |
| `TXT` | `@` | `v=spf1 include:spf.improvmx.com ~all` | `3600` |
| `TXT` | `@` | `hosting-site=tarot-del-dia-es` | `3600` |
| `TXT` | `@` | `google-site-verification=y5oDE6p4gSne7dcGB5HRXdvmWeM8St6iSi4aLYqbiFs` | `3600` |
| `TXT` | `_acme-challenge` | `ULH29pUoJ6T8LCti3oCYT3zUveH6Df8Xes_vaDmtWlA` | `3600` |

Estado documentado:
- DNS base configurado en Piensa
- Search Console verificado

## calcular-numerologia.es

Firebase project: `calc-numerologia-es`

| Tipo | Nombre | Valor | TTL |
|---|---|---|---|
| `A` | `@` | `199.36.158.100` | `3600` |
| `CNAME` | `www` | `calc-numerologia-es.web.app` | `3600` |
| `MX` | `@` | `10 mx1.improvmx.com` | `3600` |
| `MX` | `@` | `20 mx2.improvmx.com` | `3600` |
| `TXT` | `@` | `v=spf1 include:spf.improvmx.com ~all` | `3600` |
| `TXT` | `@` | `hosting-site=calc-numerologia-es` | `3600` |
| `TXT` | `@` | `google-site-verification=R7Ml-zTd4yo6NlA8mu4RWpNnE1BcQkfve3o-3MyML84` | `3600` |
| `TXT` | `_acme-challenge` | `hY5QfB1UDJHyiHmXMyjeMtQP3BlEOxBzGTK05ijkgRQ` | `3600` |

Estado documentado:
- DNS base configurado en Piensa
- Search Console verificado

## horoscopo-de-hoy.es

Firebase project: `horoscopo-hoy-es`

| Tipo | Nombre | Valor | TTL |
|---|---|---|---|
| `A` | `@` | `199.36.158.100` | `3600` |
| `CNAME` | `www` | `horoscopo-hoy-es.web.app` | `3600` |
| `MX` | `@` | `10 mx1.improvmx.com` | `3600` |
| `MX` | `@` | `20 mx2.improvmx.com` | `3600` |
| `TXT` | `@` | `v=spf1 include:spf.improvmx.com ~all` | `3600` |
| `TXT` | `@` | `hosting-site=horoscopo-hoy-es` | `3600` |
| `TXT` | `@` | `google-site-verification=J3Doot_Iz9hkGqE6i7-eKO-YPgHaEif-YnPX0NHwfX0` | `3600` |
| `TXT` | `_acme-challenge` | `EjFvRk9FSIxsE_6r9wgBAiiddpqZrB22AYnxkO23LuM` | `3600` |

Estado documentado:
- DNS base configurado en Piensa
- Search Console verificado

## Buenas prácticas operativas

1. Mantén `A @`, `CNAME www`, `TXT _acme-challenge` y `TXT hosting-site` alineados con Firebase Hosting.
2. Si Firebase pide un reto adicional para `www`, añade el `TXT _acme-challenge.www` exacto que muestre la consola. No inventes ni reutilices valores.
3. Mantén el `google-site-verification` una vez el dominio ya esté verificado en Search Console.
4. No mezcles varios `hosting-site=...` en un mismo dominio.
5. Tras cambios DNS, valida por fuera con `dig` y por aplicación con `https://dominio/ads.txt`, `https://www.dominio/ads.txt`, `https://dominio/sitemap.xml` y `https://dominio/publicidad`.
