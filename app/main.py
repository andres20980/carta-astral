"""
API web para generación de cartas astrales natales.

Endpoints:
  POST /api/parse-pdf       — Extrae datos de un certificado de nacimiento
  POST /api/calculate-chart — Calcula la carta astral
  GET  /                    — Sirve el frontend
"""

import tempfile
from pathlib import Path

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from app.pdf_parser import parse_birth_certificate
from app.chart_engine import calculate_chart
from app.interpreter import interpret_chart

app = FastAPI(title="Carta Astral", version="1.0.0")

STATIC_DIR = Path(__file__).parent / "static"


class ChartRequest(BaseModel):
    name: str
    year: int
    month: int
    day: int
    hour: int
    minute: int
    lat: float
    lng: float
    city: str = ""
    tz: str = "Europe/Madrid"


@app.post("/api/parse-pdf")
async def parse_pdf(file: UploadFile = File(...)):
    """Parsea un certificado de nacimiento PDF y devuelve los datos extraídos."""
    if not file.filename or not file.filename.lower().endswith(".pdf"):
        raise HTTPException(400, "Solo se aceptan archivos PDF")

    content = await file.read()
    if len(content) > 10 * 1024 * 1024:
        raise HTTPException(400, "Archivo demasiado grande (máx 10MB)")

    with tempfile.NamedTemporaryFile(suffix=".pdf", delete=True) as tmp:
        tmp.write(content)
        tmp.flush()
        try:
            result = parse_birth_certificate(tmp.name)
        except Exception as e:
            raise HTTPException(422, f"Error al procesar el PDF: {e}")

    # No devolver raw_text al cliente (salvo debug)
    raw = result.pop("raw_text", None)
    return result


@app.post("/api/parse-pdf-debug")
async def parse_pdf_debug(file: UploadFile = File(...)):
    """Debug: devuelve el raw_text extraído del PDF."""
    content = await file.read()
    with tempfile.NamedTemporaryFile(suffix=".pdf", delete=True) as tmp:
        tmp.write(content)
        tmp.flush()
        result = parse_birth_certificate(tmp.name)
    return {"raw_text": result.get("raw_text", ""), "ocr_used": result.get("ocr_used", False)}


@app.post("/api/calculate-chart")
async def api_calculate_chart(req: ChartRequest):
    """Calcula la carta astral a partir de los datos de nacimiento."""
    try:
        chart = calculate_chart(
            name=req.name,
            year=req.year, month=req.month, day=req.day,
            hour=req.hour, minute=req.minute,
            lat=req.lat, lng=req.lng,
            city=req.city, tz=req.tz,
        )
    except Exception as e:
        raise HTTPException(500, f"Error en el cálculo: {e}")

    return chart


@app.post("/api/interpret-chart")
async def api_interpret_chart(req: ChartRequest):
    """Calcula la carta y devuelve una interpretación con IA."""
    try:
        chart = calculate_chart(
            name=req.name,
            year=req.year, month=req.month, day=req.day,
            hour=req.hour, minute=req.minute,
            lat=req.lat, lng=req.lng,
            city=req.city, tz=req.tz,
        )
    except Exception as e:
        raise HTTPException(500, f"Error en el cálculo: {e}")

    try:
        html = await interpret_chart(chart)
    except Exception as e:
        raise HTTPException(502, f"Error al generar interpretación: {e}")

    return {"interpretation": html}


@app.get("/")
async def index():
    """Sirve el frontend."""
    return FileResponse(STATIC_DIR / "index.html")


app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")
