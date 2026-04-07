"""
Motor de cálculo de carta astral natal.

Wrapper sobre Kerykeion (Swiss Ephemeris) que devuelve un dict
serializable con todas las posiciones, aspectos y distribuciones.
"""

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

PLANET_ES = {
    "Sun": "Sol", "Moon": "Luna", "Mercury": "Mercurio",
    "Venus": "Venus", "Mars": "Marte", "Jupiter": "Júpiter",
    "Saturn": "Saturno", "Uranus": "Urano",
    "Neptune": "Neptuno", "Pluto": "Plutón",
}

PLANET_GLYPH = {
    "Sol": "☉", "Luna": "☽", "Mercurio": "☿", "Venus": "♀",
    "Marte": "♂", "Júpiter": "♃", "Saturno": "♄",
    "Urano": "♅", "Neptuno": "♆", "Plutón": "♇",
}

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


def _abs_lon(planet: dict) -> float:
    return SIGN_ORDER.index(planet["sign"]) * 30 + planet["position"]


def _deg_dms(deg: float) -> str:
    d = int(deg)
    m = int((deg - d) * 60)
    return f"{d}° {m:02d}'"


def _planet_info(p: dict) -> dict:
    name_es = PLANET_ES.get(p["name"], p["name"])
    return {
        "name": name_es,
        "glyph": PLANET_GLYPH.get(name_es, ""),
        "sign": SIGN_ES.get(p["sign"], p["sign"]),
        "degree": round(p["position"], 2),
        "degree_dms": _deg_dms(p["position"]),
        "house": HOUSE_ES.get(p["house"], p["house"]),
        "element": ELEM_ES.get(p.get("element", ""), ""),
        "modality": QUAL_ES.get(p.get("quality", ""), ""),
        "abs_longitude": round(_abs_lon(p), 2),
    }


def _compute_aspects(planets: list[dict]) -> list[dict]:
    positions = {}
    for p in planets:
        name = PLANET_ES.get(p["name"], p["name"])
        positions[name] = _abs_lon(p)

    aspects = []
    names = list(positions.keys())
    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            p1, p2 = names[i], names[j]
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


def calculate_chart(
    name: str,
    year: int, month: int, day: int,
    hour: int, minute: int,
    lat: float, lng: float,
    city: str = "",
    tz: str = "Europe/Madrid",
) -> dict:
    """
    Calcula la carta astral natal completa.

    Returns:
        dict serializable con toda la información de la carta.
    """
    subject = AstrologicalSubject(
        name, year, month, day, hour, minute,
        lng=lng, lat=lat, tz_str=tz, city=city, nation="ES",
    )

    raw_planets = [
        subject.sun, subject.moon, subject.mercury, subject.venus,
        subject.mars, subject.jupiter, subject.saturn,
        subject.uranus, subject.neptune, subject.pluto,
    ]

    planets = [_planet_info(p) for p in raw_planets]
    aspects = _compute_aspects(raw_planets)

    # Elementos
    elements = {"Fuego": 0, "Tierra": 0, "Aire": 0, "Agua": 0}
    for p in planets:
        if p["element"] in elements:
            elements[p["element"]] += 1

    # Modalidades
    modalities = {"Cardinal": 0, "Fija": 0, "Mutable": 0}
    for p in planets:
        if p["modality"] in modalities:
            modalities[p["modality"]] += 1

    # Casas
    raw_houses = [
        subject.first_house, subject.second_house, subject.third_house,
        subject.fourth_house, subject.fifth_house, subject.sixth_house,
        subject.seventh_house, subject.eighth_house, subject.ninth_house,
        subject.tenth_house, subject.eleventh_house, subject.twelfth_house,
    ]
    houses = []
    for i, h in enumerate(raw_houses, 1):
        houses.append({
            "number": i,
            "sign": SIGN_ES[h["sign"]],
            "degree": round(h["position"], 2),
            "degree_dms": _deg_dms(h["position"]),
        })

    chart = {
        "name": name,
        "birth": {
            "year": year, "month": month, "day": day,
            "hour": hour, "minute": minute,
            "lat": lat, "lng": lng, "city": city,
        },
        "ascendant": {
            "sign": SIGN_ES[subject.first_house["sign"]],
            "degree": round(subject.first_house["position"], 2),
            "degree_dms": _deg_dms(subject.first_house["position"]),
        },
        "midheaven": {
            "sign": SIGN_ES[subject.tenth_house["sign"]],
            "degree": round(subject.tenth_house["position"], 2),
            "degree_dms": _deg_dms(subject.tenth_house["position"]),
        },
        "planets": planets,
        "houses": houses,
        "aspects": aspects,
        "elements": elements,
        "modalities": modalities,
    }

    # Nodo Norte
    try:
        nn = subject.true_north_lunar_node
        if nn:
            chart["north_node"] = {
                "sign": SIGN_ES[nn["sign"]],
                "degree": round(nn["position"], 2),
                "degree_dms": _deg_dms(nn["position"]),
            }
    except Exception:
        pass

    # Quirón
    try:
        ch = subject.chiron
        if ch:
            chart["chiron"] = {
                "sign": SIGN_ES[ch["sign"]],
                "degree": round(ch["position"], 2),
                "degree_dms": _deg_dms(ch["position"]),
                "house": HOUSE_ES.get(ch["house"], ch["house"]),
            }
    except Exception:
        pass

    return chart
