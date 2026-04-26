import importlib.util
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / ".github" / "scripts" / "ad_outreach.py"
SPEC = importlib.util.spec_from_file_location("ad_outreach", MODULE_PATH)
ad_outreach = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ad_outreach)


class SyncStatusTests(unittest.TestCase):
    def test_bounce_in_thread_does_not_become_reply(self):
        prospect = {
            "email": "info@gracepazos.com",
            "status": "sent",
            "thread_id": "thread-1",
        }

        original_latest_inbound = ad_outreach.latest_inbound_from_thread
        original_postprocess = ad_outreach.postprocess_handled_conversation
        original_mail_list = ad_outreach.mail_list
        original_mail_get = ad_outreach.mail_get
        try:
            ad_outreach.latest_inbound_from_thread = lambda _token, _thread_id: {
                "thread_id": "thread-1",
                "sender": "mailer-daemon@googlemail.com",
                "snippet": "550 5.1.1 User doesn't exist: info@gracepazos.com",
            }
            ad_outreach.postprocess_handled_conversation = lambda *_args, **_kwargs: None
            ad_outreach.mail_list = lambda *_args, **_kwargs: []
            ad_outreach.mail_get = lambda *_args, **_kwargs: {}

            changed = ad_outreach.sync_status(None, [prospect])
        finally:
            ad_outreach.latest_inbound_from_thread = original_latest_inbound
            ad_outreach.postprocess_handled_conversation = original_postprocess
            ad_outreach.mail_list = original_mail_list
            ad_outreach.mail_get = original_mail_get

        self.assertEqual(len(changed), 1)
        self.assertEqual(prospect["status"], "bounced")
        self.assertEqual(prospect["validation_status"], "invalid")
        self.assertEqual(prospect["validation_reason"], "mailbox_bounced_user_unknown")
        self.assertIn("bounce_snippet", prospect)
        self.assertNotIn("reply_snippet", prospect)


class MessageBodyTests(unittest.TestCase):
    def test_render_message_body_adds_personal_context(self):
        prospect = {
            "name": "Astroworld",
            "segment": "astrologia profesional",
            "source_url": "https://astroworld.es/contacto/",
        }
        template = "Hola,\n\nTe escribo porque estamos abriendo espacios.\n"

        body = ad_outreach.render_message_body(prospect, template)

        self.assertIn("He revisado Astroworld · astrologia profesional", body)
        self.assertIn("https://astroworld.es/contacto/", body)
        self.assertTrue(body.startswith("Hola,\n\nHe revisado"))


if __name__ == "__main__":
    unittest.main()
