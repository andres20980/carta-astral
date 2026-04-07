"""
Parser de certificados de nacimiento del Registro Civil español (PDF).

Extrae nombre, fecha de nacimiento y hora de nacimiento del texto
contenido en los PDFs emitidos por la Secretaría de Estado de Justicia.

Soporta:
  - Certificados modernos (texto digital embebido) vía pdfplumber
  - Actas antiguas manuscritas (escaneadas) vía OCR con pytesseract
  - Formato moderno con campos estructurados (Nombre, Primer apellido...)
  - Formato antiguo en prosa ("se procede a inscribir el nacimiento...")
"""

import re
from pathlib import Path

import pdfplumber

try:
    import pytesseract
    from pdf2image import convert_from_path
    HAS_OCR = True
except ImportError:
    HAS_OCR = False


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
    "mil novecientos cuarenta": 1940, "mil novecientos cuarenta y uno": 1941,
    "mil novecientos cuarenta y dos": 1942, "mil novecientos cuarenta y tres": 1943,
    "mil novecientos cuarenta y cuatro": 1944, "mil novecientos cuarenta y cinco": 1945,
    "mil novecientos cuarenta y seis": 1946, "mil novecientos cuarenta y siete": 1947,
    "mil novecientos cuarenta y ocho": 1948, "mil novecientos cuarenta y nueve": 1949,
    "mil novecientos cincuenta": 1950, "mil novecientos cincuenta y uno": 1951,
    "mil novecientos cincuenta y dos": 1952, "mil novecientos cincuenta y tres": 1953,
    "mil novecientos cincuenta y cuatro": 1954, "mil novecientos cincuenta y cinco": 1955,
    "mil novecientos cincuenta y seis": 1956, "mil novecientos cincuenta y siete": 1957,
    "mil novecientos cincuenta y ocho": 1958, "mil novecientos cincuenta y nueve": 1959,
    "mil novecientos sesenta": 1960, "mil novecientos sesenta y uno": 1961,
    "mil novecientos sesenta y dos": 1962, "mil novecientos sesenta y tres": 1963,
    "mil novecientos sesenta y cuatro": 1964, "mil novecientos sesenta y cinco": 1965,
    "mil novecientos sesenta y seis": 1966, "mil novecientos sesenta y siete": 1967,
    "mil novecientos sesenta y ocho": 1968, "mil novecientos sesenta y nueve": 1969,
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


def _ocr_pdf(pdf_path: str | Path) -> str:
    """Extrae texto de un PDF escaneado usando OCR (Tesseract)."""
    if not HAS_OCR:
        return ""
    images = convert_from_path(str(pdf_path), dpi=300)
    texts = []
    for img in images:
        text = pytesseract.image_to_string(img, lang="spa")
        texts.append(text)
    return "\n".join(texts)


def _is_text_useful(text: str) -> bool:
    """Determina si el texto extraído contiene datos relevantes del acta."""
    text_norm = _normalize(text)
    # Indicadores de que hay contenido real del acta
    indicators = ["nacimiento", "inscribir", "nombre", "apellido", "hora", "hembra", "varón"]
    matches = sum(1 for ind in indicators if ind in text_norm)
    return matches >= 2


def _parse_hora(text: str) -> tuple[int, int] | None:
    """Extrae hora de nacimiento del texto.

    Soporta formatos como:
    - 'Hora de nacimiento seis cuarenta' (moderno)
    - 'a las dos horas del día' (antiguo)
    - 'a las 6:40'
    """
    text_norm = _normalize(text)

    # Formato numérico: HH:MM o HH.MM
    m = re.search(r"hora de nacimiento[^\d]*(\d{1,2})[:\.](\d{2})", text_norm)
    if m:
        return int(m.group(1)), int(m.group(2))

    # Formato texto moderno: "seis cuarenta", "nueve - treinta"
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

    # Formato antiguo: "a las dos horas" / "a las once horas"
    m = re.search(r"a\s+las?\s+(\w+)\s+horas?", text_norm)
    if m:
        h_txt = m.group(1).strip()
        hora = NUMEROS_TEXTO.get(h_txt)
        if hora is not None:
            return hora, 0
        if h_txt.isdigit():
            return int(h_txt), 0

    # Formato antiguo con minutos: "a las dos y media" / "a las tres y cuarto"
    m = re.search(r"a\s+las?\s+(\w+)\s+y\s+(media|cuarto)", text_norm)
    if m:
        h_txt = m.group(1).strip()
        hora = NUMEROS_TEXTO.get(h_txt)
        if hora is not None:
            minuto = 30 if m.group(2) == "media" else 15
            return hora, minuto

    return None


def _parse_nombre(text: str) -> str | None:
    """Extrae el nombre del inscrito (formato moderno o antiguo)."""
    # Formato moderno: "Nombre  JUAN ANTONIO"
    m = re.search(r"Nombre\s+([A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ\s\-]+)", text)
    if m:
        return m.group(1).strip().title()

    # Formato antiguo: "los nombres de (6) María Jesús"
    m = re.search(r"(?:los\s+)?nombres?\s+de\s*\(\d\)\s*([^\n]+)", text, re.IGNORECASE)
    if m:
        name = m.group(1).strip()
        # Limpiar hasta punto, coma o fin de línea
        name = re.split(r"[,.\n]", name)[0].strip()
        return name.title() if name else None

    # Formato antiguo: "Nombres y apellidos" en margen izquierdo
    m = re.search(r"Nombres?\s+y\s+apellidos?\s*[:(]?\s*\n?\s*([A-ZÁÉÍÓÚÑa-záéíóúñ][\wáéíóúñÁÉÍÓÚÑ\s\-]+)", text, re.IGNORECASE)
    if m:
        name = m.group(1).strip()
        name = re.split(r"\n", name)[0].strip()
        return name.title() if name else None

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

    # Formato moderno: "Día dos" o "Día 2" o "Día doce"
    m = re.search(r"d[ií]a\s+(\w+)", text_norm)
    if m:
        val = m.group(1)
        if val.isdigit():
            return int(val)
        v = NUMEROS_TEXTO.get(val)
        if v:
            return v

    # Formato antiguo: "del día veinticinco de junio"
    m = re.search(r"del\s+d[ií]a\s+(\w+)\s+de\s+\w+", text_norm)
    if m:
        val = m.group(1)
        if val.isdigit():
            return int(val)
        return NUMEROS_TEXTO.get(val)

    return None


def _parse_mes(text: str) -> int | None:
    """Extrae el mes de nacimiento."""
    text_norm = _normalize(text)

    # Formato moderno: "Mes junio"
    m = re.search(r"mes\s+(\w+)", text_norm)
    if m:
        v = MESES.get(m.group(1))
        if v:
            return v

    # Formato antiguo: "del día veinticinco de junio de mil..."
    m = re.search(r"del\s+d[ií]a\s+\w+\s+de\s+(\w+)\s+de\s+", text_norm)
    if m:
        return MESES.get(m.group(1))

    # Fallback: buscar "de <mes> de <año>"
    for mes_name, mes_num in MESES.items():
        if re.search(rf"de\s+{mes_name}\s+de\s+(?:mil|\d{{4}})", text_norm):
            return mes_num

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
    # Formato antiguo y moderno
    if "hembra" in text_norm or "mujer" in text_norm:
        return "F"
    # Formato antiguo: "nacimiento de una hembra" / "nacimiento de un varón"
    if re.search(r"nacimiento\s+de\s+un[ao]?\s+hembr", text_norm):
        return "F"
    return None


def _parse_lugar(text: str) -> str | None:
    """Extrae el lugar de nacimiento."""
    # Formato moderno
    m = re.search(r"Lugar\s+([^\n]+)", text)
    if m:
        return m.group(1).strip()

    # Formato antiguo: "Registro Civil de Palomero"
    m = re.search(r"Registro\s+Civil\s+de\s+([A-ZÁÉÍÓÚÑa-záéíóúñ\s]+)", text)
    if m:
        return m.group(1).strip().title()

    return None


def _parse_apellidos_from_name_line(full_name: str) -> tuple[str, str] | None:
    """Intenta separar nombre + 2 apellidos de una línea tipo 'María Jesús Martín Garrón'."""
    parts = full_name.strip().split()
    if len(parts) >= 3:
        # Asume: último = 2º apellido, penúltimo = 1er apellido
        return parts[-2].title(), parts[-1].title()
    return None


def parse_birth_certificate(pdf_path: str | Path) -> dict:
    """
    Parsea un certificado de nacimiento del Registro Civil español.

    Intenta primero pdfplumber (texto digital embebido).
    Si no extrae datos útiles, hace OCR con Tesseract.

    Returns:
        dict con claves: name, first_surname, second_surname,
                        day, month, year, hour, minute,
                        sex, birthplace, raw_text, ocr_used
    """
    pdf_path = Path(pdf_path)
    if not pdf_path.exists():
        raise FileNotFoundError(f"No se encuentra el archivo: {pdf_path}")

    # Paso 1: extraer texto digital con pdfplumber
    full_text = ""
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            text = page.extract_text() or ""
            full_text += text + "\n"

    ocr_used = False

    # Paso 2: si el texto no tiene datos útiles, intentar OCR
    if not _is_text_useful(full_text):
        if HAS_OCR:
            ocr_text = _ocr_pdf(pdf_path)
            if _is_text_useful(ocr_text):
                full_text = ocr_text
                ocr_used = True
        # Si ni pdfplumber ni OCR dieron resultado útil, seguimos con lo que hay

    result = {
        "name": _parse_nombre(full_text),
        "sex": _parse_sexo(full_text),
        "day": _parse_dia(full_text),
        "month": _parse_mes(full_text),
        "year": _parse_anno(full_text),
        "birthplace": _parse_lugar(full_text),
        "raw_text": full_text,
        "ocr_used": ocr_used,
    }

    apellidos = _parse_apellidos(full_text)
    if apellidos:
        result["first_surname"] = apellidos[0]
        result["second_surname"] = apellidos[1]
    else:
        # Intentar separar del nombre completo (formato antiguo)
        if result["name"]:
            ap = _parse_apellidos_from_name_line(result["name"])
            if ap:
                result["first_surname"] = ap[0]
                result["second_surname"] = ap[1]
                # Dejar solo el nombre de pila
                parts = result["name"].split()
                if len(parts) > 2:
                    result["name"] = " ".join(parts[:-2])
            else:
                result["first_surname"] = None
                result["second_surname"] = None
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
