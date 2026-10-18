# Generated with assistance from OpenAI GPT-5.6.

import os
import subprocess
import sys
import tempfile
import unittest


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), os.path.pardir))
VALIDATOR = os.path.join(
    ROOT, "scripts", "validate-chewing-dictionaries.py")


class ChewingDictionaryValidationTests(unittest.TestCase):
    def run_validator(self, base, *overlays):
        with tempfile.TemporaryDirectory() as temp_dir:
            base_path = os.path.join(temp_dir, "base.csv")
            with open(base_path, "w", encoding="utf-8", newline="") as output:
                output.write(base)

            command = [sys.executable, VALIDATOR, "--base", base_path]
            for index, content in enumerate(overlays):
                overlay_path = os.path.join(
                    temp_dir, "overlay-{}.csv".format(index))
                with open(
                        overlay_path, "w", encoding="utf-8",
                        newline="") as output:
                    output.write(content)
                command.extend(("--overlay", overlay_path))

            return subprocess.run(
                command, capture_output=True, text=True, check=False)

    def test_accepts_distinct_layered_entries(self):
        result = self.run_validator(
            "測試,1,ㄘㄜˋ ㄕˋ\n",
            "馬斯克,0,ㄇㄚˇ ㄙ ㄎㄜˋ\n",
            "伊隆馬斯克,0,ㄧ ㄌㄨㄥˊ ㄇㄚˇ ㄙ ㄎㄜˋ\n")

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_duplicate_entry_across_layers(self):
        result = self.run_validator(
            "測試,1,ㄘㄜˋ ㄕˋ\n",
            "測試,0,ㄘㄜˋ ㄕˋ\n")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicates", result.stderr)

    def test_rejects_phrase_and_syllable_length_mismatch(self):
        result = self.run_validator(
            "測試,1,ㄘㄜˋ ㄕˋ\n",
            "馬斯克,0,ㄇㄚˇ ㄙ\n")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("characters but", result.stderr)


if __name__ == "__main__":
    unittest.main()
