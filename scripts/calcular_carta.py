#!/usr/bin/env python3
"""
Calculador de Carta Astral Natal.

Genera las posiciones planetarias, casas, aspectos, distribución
elemental y modal para una persona a partir de sus datos de nacimiento.

Requiere: pip install kerykeion
(Swiss Ephemeris via Kerykeion v5)
"""

import argparse
import json
import sys
from dataclasses import dataclass

from kerykeion import AstrologicalSubject


SIGN_ORDER = ["Ari", "Tau", "Gem", "Can", "Leo", "Vir",
              "Lib", "Sco", "Sag", "Cap", "Aqu", "Pis"]

SIGN_ES = {
    "Ari": "Aries", "Tau": "Tauro", "Gem": "Géminis", "Can": "Cáncer",
    "Leo": "Leo", "Vir": "Virgo", "Lib": "Libra", "Sco": "Escorpio",
    "Sag": "Sagitario", "Cap": "Capricornio", "Aqu": "Acuario", "Pis": "Piscis",
}

HOUSE_ES = {
    "First_House": "I", "Second_House": "II", "Third_House": "III",
    "Fourth_House": "IV", "Fifth_House": "V", "Sixth_House": "VI",
    "Seventh_House": "VII", "Eighth_House": "VIII", "Ninth_House": "IX",
    "Tenth_House": "X", "Eleventh_House": "XI", "Twelfth_House": "XII",
}

ELEM_ES = {"Fire": "Fuego", "Earth": "Tierra", "Air": "Aire", "Water": "Agua"}
QUAL_ES = {"Cardinal": "Cardinal", "Fixed": "Fija", "Mutable": "Mutable"}

ASPECTS_DEF = {
    "Conjunción": (0, 8),
    "Oposición": (180, 8),
    "Trígono": (120, 8),
    "Cuadratura": (90, 7),
    "Sextil": (60, 6),
    "Quincuncio": (150, 3),
}

ASPECT_GLYPH = {
    "Conjunción": "☌", "Oposición": "☍", "Trígono": "△",
    "Cuadratura": "□", "Sextil": "✱", "Quincuncio": "⚻",
}


def abs_longitude(planet: dict) -> float:
    """Convierte signo + posición a longitud eclíptica absoluta (0-360)."""
    sign_idx = SIGN_ORDER.index(planet["sign"])
    return sign_idx * 30 + planet["position"]


def deg_to_dms(deg: float) -> str:
    """Convierte grados decimales a formato grado° minuto'."""
    d = int(deg)
    m = int((deg - d) * 60)
    return f"{d}° {m:02d}'"


def compute_subject(name: str, year: int, month: int, day: int,
                    hour: int, minute: int, lat: float, lng: float,
                    city: str = "Barcelona",
                    tz: str = "Europe/Madrid") -> AstrologicalSubject:
    """Crea el sujeto astrológico con Kerykeion."""
    return AstrologicalSubject(
        name, year, month, day, hour, minute,
        lng=lng, lat=lat, tz_str=tz, city=city, nation="ES"
    )


def get_planets(subject: AstrologicalSubject) -> list[dict]:
    """Devuelve lista de planetas principales."""
    return [
        subject.sun, subject.moon, subject.mercury, subject.venus,
        subject.mars, subject.jupiter, subject.saturn,
        subject.uranus, subject.neptune, subject.pluto,
    ]


def get_houses(subject: AstrologicalSubject) -> list[dict]:
    """Devuelve lista de las 12 casas."""
    return [
        subject.first_house, subject.second_house, subject.third_house,
        subject.fourth_house, subject.fifth_house, subject.sixth_house,
        subject.seventh_house, subject.eighth_house, subject.ninth_house,
        subject.tenth_house, subject.eleventh_house, subject.twelfth_house,
    ]


def compute_aspects(planets: list[dict]) -> list[dict]:
    """Calcula aspectos entre todos los pares de planetas."""
    names_es = {
        "Sun": "Sol", "Moon": "Luna", "Mercury": "Mercurio",
        "Venus": "Venus", "Mars": "Marte", "Jupiter": "Júpiter",
        "Saturn": "Saturno", "Uranus": "Urano",
        "Neptune": "Neptuno", "Pluto": "Plutón",
    }

    positions = {}
    for p in planets:
        name = names_es.get(p["name"], p["name"])
        positions[name] = abs_longitude(p)

    aspects = []
    planet_names = list(positions.keys())
    for i in range(len(planet_names)):
        for j in range(i + 1, len(planet_names)):
            p1, p2 = planet_names[i], planet_names[j]
            diff = abs(positions[p1] - positions[p2])
            if diff > 180:
                diff = 360 - diff
            for asp_name, (angle, orb) in ASPECTS_DEF.items():
                actual_orb = abs(diff - angle)
                if actual_orb <= orb:
                    aspects.append({
                        "p1": p1,
                        "p2": p2,
                        "aspect": asp_name,
                        "glyph": ASPECT_GLYPH[asp_name],
                        "orb": round(actual_orb, 1),
                    })
    return aspects


def compute_elements(planets: list[dict]) -> dict[str, int]:
    """Cuenta planetas por elemento."""
    elements = {"Fire": 0, "Earth": 0, "Air": 0, "Water": 0}
    for p in planets:
        elem = p.get("element", "")
        if elem in elements:
            elements[elem] += 1
    return elements


def compute_modalities(planets: list[dict]) -> dict[str, int]:
    """Cuenta planetas por modalidad."""
    qualities = {"Cardinal": 0, "Fixed": 0, "Mutable": 0}
    for p in planets:
        q = p.get("quality", "")
        if q in qualities:
            qualities[q] += 1
    return qualities


def print_report(subject: AstrologicalSubject) -> None:
    """Imprime el informe completo en formato texto."""
    planets = get_planets(subject)
    houses = get_houses(subject)

    print(f"\n{'='*60}")
    print(f"  CARTA ASTRAL NATAL — {subject.name.upper()}")
    print(f"{'='*60}\n")

    # Posiciones planetarias
    print("POSICIONES PLANETARIAS")
    print("-" * 60)
    print(f"{'Planeta':<12} {'Signo':<14} {'Grado':<10} {'Casa':<6} {'Elem':<8} {'Modal':<8}")
    print("-" * 60)
    for p in planets:
        sign = SIGN_ES.get(p["sign"], p["sign"])
        house = HOUSE_ES.get(p["house"], p["house"])
        elem = ELEM_ES.get(p.get("element", ""), "")
        qual = QUAL_ES.get(p.get("quality", ""), "")
        print(f"{p['name']:<12} {sign:<14} {deg_to_dms(p['position']):<10} {house:<6} {elem:<8} {qual:<8}")

    # Puntos cardinales
    print(f"\nPUNTOS CARDINALES")
    print("-" * 40)
    asc = subject.first_house
    mc = subject.tenth_house
    print(f"Ascendente:  {SIGN_ES[asc['sign']]} {deg_to_dms(asc['position'])}")
    print(f"Medio Cielo: {SIGN_ES[mc['sign']]} {deg_to_dms(mc['position'])}")

    # Casas
    print(f"\nCÚSPIDES DE LAS CASAS (Placidus)")
    print("-" * 40)
    for i, h in enumerate(houses, 1):
        print(f"Casa {i:>2}: {SIGN_ES[h['sign']]:<14} {deg_to_dms(h['position'])}")

    # Nodo Norte
    try:
        nn = subject.true_north_lunar_node
        if nn:
            print(f"\nNodo Norte:  {SIGN_ES[nn['sign']]} {deg_to_dms(nn['position'])}")
    except Exception:
        pass

    # Quirón
    try:
        ch = subject.chiron
        if ch:
            house = HOUSE_ES.get(ch["house"], ch["house"])
            print(f"Quirón:      {SIGN_ES[ch['sign']]} {deg_to_dms(ch['position'])} (Casa {house})")
    except Exception:
        pass

    # Aspectos
    aspects = compute_aspects(planets)
    print(f"\nASPECTOS NATALES")
    print("-" * 50)
    for a in aspects:
        print(f"{a['p1']:<10} {a['glyph']} {a['aspect']:<12} {a['p2']:<10} (orbe: {a['orb']}°)")

    # Elementos
    elements = compute_elements(planets)
    print(f"\nDISTRIBUCIÓN ELEMENTAL")
    print("-" * 30)
    for k, v in elements.items():
        print(f"{ELEM_ES[k]:<8}: {v}")

    # Modalidades
    modalities = compute_modalities(planets)
    print(f"\nMODALIDADES")
    print("-" * 30)
    for k, v in modalities.items():
        print(f"{QUAL_ES[k]:<10}: {v}")

    print(f"\n{'='*60}\n")


def export_json(subject: AstrologicalSubject, output_path: str) -> None:
    """Exporta los datos calculados a JSON."""
    planets = get_planets(subject)

    data = {
        "name": subject.name,
        "birth": {
            "year": subject.year,
            "month": subject.month,
            "day": subject.day,
            "hour": subject.hour,
            "minute": subject.minute,
            "lat": subject.lat,
            "lng": subject.lng,
            "city": subject.city,
            "tz": subject.tz_str,
        },
        "ascendant": {
            "sign": SIGN_ES[subject.first_house["sign"]],
            "degree": round(subject.first_house["position"], 2),
        },
        "midheaven": {
            "sign": SIGN_ES[subject.tenth_house["sign"]],
            "degree": round(subject.tenth_house["position"], 2),
        },
        "planets": [],
        "houses": [],
        "aspects": compute_aspects(planets),
        "elements": {ELEM_ES[k]: v for k, v in compute_elements(planets).items()},
        "modalities": {QUAL_ES[k]: v for k, v in compute_modalities(planets).items()},
    }

    for p in planets:
        data["planets"].append({
            "name": p["name"],
            "sign": SIGN_ES.get(p["sign"], p["sign"]),
            "degree": round(p["position"], 2),
            "house": HOUSE_ES.get(p["house"], p["house"]),
            "element": ELEM_ES.get(p.get("element", ""), ""),
            "modality": QUAL_ES.get(p.get("quality", ""), ""),
            "abs_longitude": round(abs_longitude(p), 2),
        })

    for i, h in enumerate(get_houses(subject), 1):
        data["houses"].append({
            "number": i,
            "sign": SIGN_ES[h["sign"]],
            "degree": round(h["position"], 2),
        })

    try:
        nn = subject.true_north_lunar_node
        if nn:
            data["north_node"] = {
                "sign": SIGN_ES[nn["sign"]],
                "degree": round(nn["position"], 2),
            }
    except Exception:
        pass

    try:
        ch = subject.chiron
        if ch:
            data["chiron"] = {
                "sign": SIGN_ES[ch["sign"]],
                "degree": round(ch["position"], 2),
                "house": HOUSE_ES.get(ch["house"], ch["house"]),
            }
    except Exception:
        pass

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"Datos exportados a: {output_path}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Calculador de Carta Astral Natal (Swiss Ephemeris / Kerykeion v5)"
    )
    parser.add_argument("--name", required=True, help="Nombre de la persona")
    parser.add_argument("--date", required=True, help="Fecha de nacimiento (YYYY-MM-DD)")
    parser.add_argument("--time", required=True, help="Hora de nacimiento (HH:MM, 24h)")
    parser.add_argument("--lat", type=float, required=True, help="Latitud del lugar de nacimiento")
    parser.add_argument("--lng", type=float, required=True, help="Longitud del lugar de nacimiento")
    parser.add_argument("--city", default="Barcelona", help="Ciudad de nacimiento (default: Barcelona)")
    parser.add_argument("--tz", default="Europe/Madrid", help="Zona horaria (default: Europe/Madrid)")
    parser.add_argument("--json", dest="json_output", help="Ruta para exportar datos en JSON")

    args = parser.parse_args()

    year, month, day = map(int, args.date.split("-"))
    hour, minute = map(int, args.time.split(":"))

    subject = compute_subject(
        name=args.name,
        year=year, month=month, day=day,
        hour=hour, minute=minute,
        lat=args.lat, lng=args.lng,
        city=args.city, tz=args.tz,
    )

    print_report(subject)

    if args.json_output:
        export_json(subject, args.json_output)


if __name__ == "__main__":
    main()
