# Generated with assistance from OpenAI GPT-5.6.

from ctypes import byref, c_uint, create_string_buffer
import importlib
import os
import sys
import tempfile
import unittest


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), os.path.pardir))
PYTHON_DIR = os.path.join(ROOT, "python")
if PYTHON_DIR not in sys.path:
    sys.path.insert(0, PYTHON_DIR)

libchewing = importlib.import_module("libchewing")
binding = importlib.import_module("libchewing.libchewing")
CHEWING_DATA_DIR = libchewing.CHEWING_DATA_DIR
ChewingContext = libchewing.ChewingContext
_libchewing = binding._libchewing


class LibchewingBindingTests(unittest.TestCase):
    def test_context_input_and_lifetime(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            user_path = os.path.join(temp_dir, "chewing.sqlite3")
            context = ChewingContext(
                syspath=CHEWING_DATA_DIR,
                userpath=user_path)
            try:
                self.assertEqual(
                    _libchewing.chewing_version().decode("ascii"),
                    "0.13.1")

                for key in "w91o3g4":
                    self.assertEqual(context.handle_Default(ord(key)), 0)

                self.assertTrue(
                    context.buffer_Check() or context.commit_Check())
                if context.buffer_Check():
                    self.assertTrue(
                        context.buffer_String().decode("utf-8"))
            finally:
                context.close()

            context.close()
            with self.assertRaisesRegex(RuntimeError, "closed"):
                context.buffer_Check()

    def test_userphrase_buffers_follow_declared_abi(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            user_path = os.path.join(temp_dir, "chewing.sqlite3")
            context = ChewingContext(
                syspath=CHEWING_DATA_DIR,
                userpath=user_path)
            phrase = "測試詞"
            bopomofo = "ㄘㄜˋ ㄕˋ ㄘˊ"
            try:
                self.assertEqual(
                    context.userphrase_add(
                        phrase.encode("utf-8"),
                        bopomofo.encode("utf-8")),
                    1)
                self.assertEqual(context.userphrase_enumerate(), 0)

                phrase_len = c_uint()
                bopomofo_len = c_uint()
                enumerated = []
                while context.userphrase_has_next(
                        byref(phrase_len),
                        byref(bopomofo_len)):
                    phrase_buffer = create_string_buffer(phrase_len.value)
                    bopomofo_buffer = create_string_buffer(
                        bopomofo_len.value)
                    self.assertEqual(
                        context.userphrase_get(
                            phrase_buffer,
                            phrase_len,
                            bopomofo_buffer,
                            bopomofo_len),
                        0)
                    enumerated.append((
                        phrase_buffer.value.decode("utf-8"),
                        bopomofo_buffer.value.decode("utf-8")))

                self.assertIn((phrase, bopomofo), enumerated)
            finally:
                context.close()


if __name__ == "__main__":
    unittest.main()
