# carta-astral

Generador de cartas astrales natales con cálculos astronómicos de precisión (Swiss Ephemeris).

## Requisitos

```bash
pip install kerykeion
```

> Kerykeion v5 utiliza la Swiss Ephemeris internamente (misma base de Astro.com).

## Uso

```bash
# Informe en terminal
python scripts/calcular_carta.py \
  --name "Andrés" \
  --date 1980-09-02 \
  --time 06:40 \
  --lat 41.4292 \
  --lng 2.1435

# Con exportación JSON
python scripts/calcular_carta.py \
  --name "Patricia" \
  --date 1987-08-12 \
  --time 09:30 \
  --lat 41.4027 \
  --lng 2.1269 \
  --json output/patricia.json
```

### Parámetros

| Parámetro | Requerido | Descripción |
|---|---|---|
| `--name` | sí | Nombre de la persona |
| `--date` | sí | Fecha de nacimiento (YYYY-MM-DD) |
| `--time` | sí | Hora de nacimiento (HH:MM, formato 24h) |
| `--lat` | sí | Latitud del lugar de nacimiento |
| `--lng` | sí | Longitud del lugar de nacimiento |
| `--city` | no | Ciudad (default: Barcelona) |
| `--tz` | no | Zona horaria IANA (default: Europe/Madrid) |
| `--json` | no | Ruta para exportar datos en JSON |

## Estructura

```
carta-astral/
├── scripts/
│   └── calcular_carta.py    # Script principal de cálculo
├── output/
│   ├── carta_astral_andres_sanchez.md
│   └── carta_astral_patricia_andaluz.md
├── requirements.txt
└── README.md
```

## Metodología

- **Motor**: Swiss Ephemeris (alta precisión)
- **Sistema de casas**: Placidus
- **Zodíaco**: Tropical
- **Orbes**: Conjunción/Oposición 8°, Trígono/Cuadratura 7-8°, Sextil 6°, Quincuncio 3°
- **Puntos calculados**: 10 planetas + Quirón + Nodo Norte + 12 casas + aspectos mayores

## Cartas generadas

- [Andrés Sánchez Martín](output/carta_astral_andres_sanchez.md) — 2 sept 1980, Barcelona
- [Patricia María Andaluz Barragán](output/carta_astral_patricia_andaluz.md) — 12 ago 1987, Barcelona
