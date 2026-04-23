import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SOURCE_MILESTONES = REPO_ROOT / "docs" / "GROWTH_MILESTONES.json"
SCRIPT_PATH = REPO_ROOT / ".github" / "scripts" / "growth-milestone-check.js"


class GrowthMilestoneCheckTests(unittest.TestCase):
    def test_preserves_manual_auto_fields(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / "docs").mkdir()
            shutil.copy2(SOURCE_MILESTONES, root / "docs" / "GROWTH_MILESTONES.json")
            (root / ".github").symlink_to(REPO_ROOT / ".github", target_is_directory=True)
            (root / "shared").symlink_to(REPO_ROOT / "shared", target_is_directory=True)
            (root / "sites").symlink_to(REPO_ROOT / "sites", target_is_directory=True)

            env = os.environ.copy()
            env.update({
                "SESSIONS": "81",
                "USERS": "79",
                "VIEWS": "82",
                "DURATION": "6.4",
                "BOUNCE": "0.9259",
                "ORGANIC_SESSIONS": "1",
                "CHART_CALCULATED": "2",
                "INTERPRETATION_GENERATED": "0",
                "GSC_VERIFIED_SITE_COUNT": "5",
            })

            result = subprocess.run(
                ["node", str(root / ".github" / "scripts" / "growth-milestone-check.js")],
                cwd=root,
                env=env,
                check=True,
                capture_output=True,
                text=True,
            )

            self.assertIn("### 🚀 Progreso de hitos de crecimiento", result.stdout)

            payload = json.loads((root / "docs" / "GROWTH_MILESTONES.json").read_text(encoding="utf-8"))
            self.assertIn("auto", payload)
            self.assertIn("adsense", payload["auto"])
            self.assertEqual(payload["auto"]["adsense"]["publisher_id"], "pub-9368517395014039")
            self.assertEqual(payload["auto"]["adsense"]["earliest_reapply_date"], "2026-07-01")


if __name__ == "__main__":
    unittest.main()
