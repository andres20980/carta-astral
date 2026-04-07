"""
Interpretación de carta astral con Gemini (free tier).

Usa la API REST directamente con httpx — sin SDK pesado.
"""

import os
import json
import httpx

GEMINI_KEY = os.environ.get("GEMINI_API_KEY", "")
GEMINI_MODEL = "gemini-2.5-flash"
GEMINI_URL = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent"

SYSTEM_PROMPT = """\
Eres un astrólogo profesional que interpreta cartas astrales natales.
Redacta una interpretación exhaustiva y personalizada en español, con tono cercano (tutea al lector).
Estructura tu respuesta con estas secciones en HTML (usa <h3>, <p>, <ul>, <li>):

<h3>☉ Tu esencia: Sol en {signo}</h3>
<h3>☽ Tu mundo emocional: Luna en {signo}</h3>
<h3>↑ Tu máscara social: Ascendente en {signo}</h3>
<h3>♀♂ Amor y deseo</h3> (Venus y Marte)
<h3>🪐 Los grandes maestros</h3> (Júpiter, Saturno)
<h3>⚡ Planetas generacionales</h3> (Urano, Neptuno, Plutón)
<h3>🏠 Las casas más destacadas</h3> (donde hay más planetas)
<h3>🔗 Aspectos clave</h3> (conjunciones y oposiciones principales)
<h3>🔮 Síntesis general</h3> (2-3 párrafos de resumen)

Sé específico con los grados y las casas. Explica qué significa cada posición en la vida cotidiana.
No repitas la posición sin explicarla. Cada párrafo debe aportar insight práctico.
Extensión: 800-1200 palabras. Solo devuelve el HTML, sin markdown ni bloques de código.\
"""


def _build_chart_summary(chart: dict) -> str:
    """Convierte el dict de la carta en un prompt textual para Gemini."""
    lines = []
    b = chart.get("birth", {})
    lines.append(f"Nacimiento: {b.get('day')}/{b.get('month')}/{b.get('year')} "
                 f"a las {b.get('hour')}:{b.get('minute'):02d}, "
                 f"{b.get('city', 'ubicación desconocida')} "
                 f"({b.get('lat')}, {b.get('lng')})")

    asc = chart.get("ascendant", {})
    lines.append(f"Ascendente: {asc.get('sign')} {asc.get('degree_dms', '')}")

    mc = chart.get("midheaven", {})
    lines.append(f"Medio Cielo (MC): {mc.get('sign')} {mc.get('degree_dms', '')}")

    lines.append("\nPlanetas:")
    for p in chart.get("planets", []):
        lines.append(f"  {p['glyph']} {p['name']}: {p['sign']} {p['degree_dms']} — Casa {p['house']}")

    nn = chart.get("north_node")
    if nn:
        lines.append(f"  Nodo Norte: {nn['sign']} {nn.get('degree_dms', '')}")

    lines.append("\nCasas:")
    for h in chart.get("houses", []):
        lines.append(f"  Casa {h['number']}: {h['sign']} {h['degree_dms']}")

    lines.append("\nAspectos principales:")
    for a in chart.get("aspects", []):
        if a.get("orb", 99) <= 5:
            lines.append(f"  {a['p1']} {a['glyph']} {a['aspect']} {a['p2']} (orbe {a['orb']}°)")

    elem = chart.get("elements", {})
    lines.append(f"\nDistribución elementos: {json.dumps(elem, ensure_ascii=False)}")
    mod = chart.get("modalities", {})
    lines.append(f"Distribución modalidades: {json.dumps(mod, ensure_ascii=False)}")

    return "\n".join(lines)


async def interpret_chart(chart: dict) -> str:
    """Envía la carta a Gemini y devuelve HTML con la interpretación."""
    if not GEMINI_KEY:
        raise RuntimeError("GEMINI_API_KEY no configurada")

    chart_text = _build_chart_summary(chart)

    payload = {
        "system_instruction": {"parts": [{"text": SYSTEM_PROMPT}]},
        "contents": [{"parts": [{"text": f"Interpreta esta carta astral natal:\n\n{chart_text}"}]}],
        "generationConfig": {
            "temperature": 0.8,
            "maxOutputTokens": 4096,
        },
    }

    async with httpx.AsyncClient(timeout=60) as client:
        resp = await client.post(
            GEMINI_URL,
            params={"key": GEMINI_KEY},
            json=payload,
        )
        resp.raise_for_status()

    data = resp.json()
    text = data["candidates"][0]["content"]["parts"][0]["text"]
    # Limpiar posibles wrappers markdown
    if text.startswith("```html"):
        text = text[7:]
    if text.startswith("```"):
        text = text[3:]
    if text.endswith("```"):
        text = text[:-3]
    return text.strip()
