"""
Parser de certificados de nacimiento del Registro Civil español (PDF).

Extrae nombre, fecha de nacimiento y hora de nacimiento del texto OCR
contenido en los PDFs emitidos por la Secretaría de Estado de Justicia.
"""

import re
from pathlib import Path

import pdfplumber


MESES = {
    "enero": 1, "febrero": 2, "marzo": 3, "abril": 4,
    "mayo": 5, "junio": 6, "julio": 7, "agosto": 8,
    "septiembre": 9, "octubre": 10, "noviembre": 11, "diciembre": 12,
}

NUMEROS_TEXTO = {
    "una": 1, "dos": 2, "tres": 3, "cuatro": 4, "cinco": 5,
    "seis": 6, "siete": 7, "ocho": 8, "nueve": 9, "diez": 10,
    "once": 11, "doce": 12, "trece": 13, "catorce": 14, "quince": 15,
    "dieciséis": 16, "dieciseis": 16, "diecisiete": 17, "dieciocho": 18,
    "diecinueve": 19, "veinte": 20, "veintiuna": 21, "veintiuno": 21,
    "veintidos": 22, "veintidós": 22, "veintitrés": 23, "veintitres": 23,
    "veinticuatro": 24,
}

ANNO_TEXTO = {
    "mil novecientos setenta": 1970, "mil novecientos setenta y uno": 1971,
    "mil novecientos setenta y dos": 1972, "mil novecientos setenta y tres": 1973,
    "mil novecientos setenta y cuatro": 1974, "mil novecientos setenta y cinco": 1975,
    "mil novecientos setenta y seis": 1976, "mil novecientos setenta y siete": 1977,
    "mil novecientos setenta y ocho": 1978, "mil novecientos setenta y nueve": 1979,
    "mil novecientos ochenta": 1980, "mil novecientos ochenta y uno": 1981,
    "mil novecientos ochenta y dos": 1982, "mil novecientos ochenta y tres": 1983,
    "mil novecientos ochenta y cuatro": 1984, "mil novecientos ochenta y cinco": 1985,
    "mil novecientos ochenta y seis": 1986, "mil novecientos ochenta y siete": 1987,
    "mil novecientos ochenta y ocho": 1988, "mil novecientos ochenta y nueve": 1989,
    "mil novecientos noventa": 1990, "mil novecientos noventa y uno": 1991,
    "mil novecientos noventa y dos": 1992, "mil novecientos noventa y tres": 1993,
    "mil novecientos noventa y cuatro": 1994, "mil novecientos noventa y cinco": 1995,
    "mil novecientos noventa y seis": 1996, "mil novecientos noventa y siete": 1997,
    "mil novecientos noventa y ocho": 1998, "mil novecientos noventa y nueve": 1999,
    "dos mil": 2000,
}


def _normalize(text: str) -> str:
    """Normaliza texto: minúsculas, espacios simples."""
    text = text.lower().strip()
    text = re.sub(r"\s+", " ", text)
    return text


def _parse_hora(text: str) -> tuple[int, int] | None:
    """Extrae hora de nacimiento del texto.

    Soporta formatos como:
    - 'Hora de nacimiento seis cuarenta'
    - 'Hora de nacimiento nueve - Treinta'
    - 'Hora de nacimiento las 6:40'
    """
    text_norm = _normalize(text)

    # Formato numérico: HH:MM o HH.MM
    m = re.search(r"hora de nacimiento[^\d]*(\d{1,2})[:\.](\d{2})", text_norm)
    if m:
        return int(m.group(1)), int(m.group(2))

    # Formato texto: "seis cuarenta", "nueve - treinta", "nueve-treinta"
    m = re.search(
        r"hora de nacimiento\s+[^\w]*\s*(\w+)\s*[-–—]?\s*(\w+)",
        text_norm,
    )
    if m:
        h_txt = m.group(1).strip()
        m_txt = m.group(2).strip()

        hora = NUMEROS_TEXTO.get(h_txt)
        minuto = NUMEROS_TEXTO.get(m_txt)

        # "cuarenta" no está en NUMEROS_TEXTO, tratamos aparte
        if minuto is None and m_txt == "cuarenta":
            minuto = 40
        if minuto is None and m_txt == "treinta":
            minuto = 30
        if minuto is None and m_txt == "cincuenta":
            minuto = 50

        if hora is not None and minuto is not None:
            return hora, minuto

    return None


def _parse_nombre(text: str) -> str | None:
    """Extrae el nombre del inscrito."""
    m = re.search(r"Nombre\s+([A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ\s\-]+)", text)
    if m:
        return m.group(1).strip().title()
    return None


def _parse_apellidos(text: str) -> tuple[str, str] | None:
    """Extrae primer y segundo apellido."""
    m1 = re.search(r"Primer apellido\s*([A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ\s]+)", text)
    m2 = re.search(r"Segundo apellido\s*([A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ\s]+)", text)
    if m1 and m2:
        return m1.group(1).strip().title(), m2.group(1).strip().title()
    return None


def _parse_dia(text: str) -> int | None:
    """Extrae el día de nacimiento."""
    text_norm = _normalize(text)

    # "Día dos" o "Día 2" o "Día doce"
    m = re.search(r"d[ií]a\s+(\w+)", text_norm)
    if m:
        val = m.group(1)
        if val.isdigit():
            return int(val)
        return NUMEROS_TEXTO.get(val)
    return None


def _parse_mes(text: str) -> int | None:
    """Extrae el mes de nacimiento."""
    text_norm = _normalize(text)
    m = re.search(r"mes\s+(\w+)", text_norm)
    if m:
        return MESES.get(m.group(1))
    return None


def _parse_anno(text: str) -> int | None:
    """Extrae el año de nacimiento."""
    text_norm = _normalize(text)

    # Formato texto: "Año mil novecientos ochenta"
    for anno_txt, anno_val in sorted(ANNO_TEXTO.items(), key=lambda x: -len(x[0])):
        if anno_txt in text_norm:
            return anno_val

    # Formato numérico
    m = re.search(r"a[ñn]o\s+(\d{4})", text_norm)
    if m:
        return int(m.group(1))

    # "de 19XX" o "de 20XX"
    m = re.search(r"de\s+(19\d{2}|20\d{2})", text_norm)
    if m:
        return int(m.group(1))

    return None


def _parse_sexo(text: str) -> str | None:
    """Extrae el sexo."""
    text_norm = _normalize(text)
    if "varón" in text_norm or "varon" in text_norm:
        return "M"
    if "hembra" in text_norm or "mujer" in text_norm:
        return "F"
    return None


def _parse_lugar(text: str) -> str | None:
    """Extrae el lugar de nacimiento."""
    m = re.search(r"Lugar\s+([^\n]+)", text)
    if m:
        return m.group(1).strip()
    return None


def parse_birth_certificate(pdf_path: str | Path) -> dict:
    """
    Parsea un certificado de nacimiento del Registro Civil español.

    Returns:
        dict con claves: name, first_surname, second_surname,
                        day, month, year, hour, minute,
                        sex, birthplace, raw_text
    """
    pdf_path = Path(pdf_path)
    if not pdf_path.exists():
        raise FileNotFoundError(f"No se encuentra el archivo: {pdf_path}")

    full_text = ""
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            text = page.extract_text() or ""
            full_text += text + "\n"

    result = {
        "name": _parse_nombre(full_text),
        "sex": _parse_sexo(full_text),
        "day": _parse_dia(full_text),
        "month": _parse_mes(full_text),
        "year": _parse_anno(full_text),
        "birthplace": _parse_lugar(full_text),
        "raw_text": full_text,
    }

    apellidos = _parse_apellidos(full_text)
    if apellidos:
        result["first_surname"] = apellidos[0]
        result["second_surname"] = apellidos[1]
    else:
        result["first_surname"] = None
        result["second_surname"] = None

    hora = _parse_hora(full_text)
    if hora:
        result["hour"], result["minute"] = hora
    else:
        result["hour"] = None
        result["minute"] = None

    return result
