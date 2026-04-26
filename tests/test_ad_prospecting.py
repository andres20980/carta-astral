import importlib.util
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / ".github" / "scripts" / "ad_prospecting.py"
SPEC = importlib.util.spec_from_file_location("ad_prospecting", MODULE_PATH)
ad_prospecting = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ad_prospecting)


class CandidateSourceTests(unittest.TestCase):
    def test_candidate_requires_public_contact_source(self):
        result = {
            "title": "Tarot Luna",
            "snippet": "Lecturas de tarot y astrologia",
            "link": "https://tarotluna.es/",
        }
        page_text = "Tarot y astrologia info@tarotluna.es"

        candidate = ad_prospecting.candidate_from(
            "info@tarotluna.es",
            result,
            page_text,
            "2026-04-26",
        )

        self.assertIsNone(candidate)

    def test_candidate_accepts_contact_page_with_visible_email(self):
        result = {
            "title": "Contacto - Tarot Luna",
            "snippet": "Contacto profesional para lecturas de tarot y astrologia",
            "link": "https://tarotluna.es/contacto/",
        }
        page_text = "Tarot y astrologia mailto:info@tarotluna.es info@tarotluna.es"

        candidate = ad_prospecting.candidate_from(
            "info@tarotluna.es",
            result,
            page_text,
            "2026-04-26",
        )

        self.assertIsNotNone(candidate)
        self.assertEqual(candidate["source_kind"], "public_contact_page")
        self.assertTrue(candidate["contact_evidence"]["email_visible"])


if __name__ == "__main__":
    unittest.main()
