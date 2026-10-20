# Generated with assistance from OpenAI GPT-5.6.

from contextlib import closing
from ctypes import byref, c_uint, create_string_buffer
import importlib
import os
import sqlite3
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
CHEWING_DICTIONARY_DIR = libchewing.CHEWING_DICTIONARY_DIR
PIME_DICTIONARIES = libchewing.PIME_DICTIONARIES
PIME_SEARCH_PATH = ";".join((CHEWING_DICTIONARY_DIR, CHEWING_DATA_DIR))
ChewingContext = libchewing.ChewingContext
_libchewing = binding._libchewing


def _create_legacy_user_dictionary(path):
    with closing(sqlite3.connect(path)) as connection:
        connection.execute(
            "CREATE TABLE userphrase_v1 ("
            "time INTEGER, user_freq INTEGER, max_freq INTEGER, "
            "orig_freq INTEGER, length INTEGER, "
            "phone_0 INTEGER, phone_1 INTEGER, phone_2 INTEGER, "
            "phone_3 INTEGER, phone_4 INTEGER, phone_5 INTEGER, "
            "phone_6 INTEGER, phone_7 INTEGER, phone_8 INTEGER, "
            "phone_9 INTEGER, phone_10 INTEGER, phrase TEXT, "
            "PRIMARY KEY ("
            "phone_0, phone_1, phone_2, phone_3, phone_4, phone_5, "
            "phone_6, phone_7, phone_8, phone_9, phone_10, phrase"
            "))")
        connection.execute(
            "INSERT INTO userphrase_v1 VALUES "
            "(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (186613, 9318, 9318, 9318, 2, 10268, 8708,
             0, 0, 0, 0, 0, 0, 0, 0, 0, "測試"))
        connection.commit()


def _create_legacy_candidate_dictionary(path):
    with closing(sqlite3.connect(path)) as connection:
        connection.execute(
            "CREATE TABLE userphrase_v1 ("
            "time INTEGER, user_freq INTEGER, max_freq INTEGER, "
            "orig_freq INTEGER, length INTEGER, "
            "phone_0 INTEGER, phone_1 INTEGER, phone_2 INTEGER, "
            "phone_3 INTEGER, phone_4 INTEGER, phone_5 INTEGER, "
            "phone_6 INTEGER, phone_7 INTEGER, phone_8 INTEGER, "
            "phone_9 INTEGER, phone_10 INTEGER, phrase TEXT, "
            "PRIMARY KEY ("
            "phone_0, phone_1, phone_2, phone_3, phone_4, phone_5, "
            "phone_6, phone_7, phone_8, phone_9, phone_10, phrase"
            "))")
        rows = (
            (143157, 114, 114, 0, 1, 3715, "你"),
            (160001, 129, 129, 0, 1, 3715, "妳"),
        )
        connection.executemany(
            "INSERT INTO userphrase_v1 VALUES ("
            "?, ?, ?, ?, ?, ?, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, ?)",
            rows)
        connection.commit()


def _get_userphrases(context):
    phrase_len = c_uint()
    bopomofo_len = c_uint()
    phrases = set()
    context.userphrase_enumerate()
    while context.userphrase_has_next(
            byref(phrase_len), byref(bopomofo_len)):
        phrase_buffer = create_string_buffer(phrase_len.value)
        bopomofo_buffer = create_string_buffer(bopomofo_len.value)
        if context.userphrase_get(
                phrase_buffer,
                phrase_len,
                bopomofo_buffer,
                bopomofo_len) != 0:
            raise AssertionError("Unable to read a libchewing user phrase")
        phrases.add((
            phrase_buffer.value.decode("utf-8"),
            bopomofo_buffer.value.decode("utf-8")))
    return phrases


class LibchewingBindingTests(unittest.TestCase):
    def test_dictionary_list_excludes_portable_user_dictionaries(self):
        self.assertEqual(
            PIME_DICTIONARIES,
            ("word.dat", "tsi.dat", "pime.dat", "pime-ai.dat"))

    def test_context_input_and_lifetime(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            user_path = os.path.join(temp_dir, "chewing.sqlite3")
            context = ChewingContext(
                syspath=PIME_SEARCH_PATH,
                userpath=user_path,
                dictionaries=PIME_DICTIONARIES)
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
                syspath=PIME_SEARCH_PATH,
                userpath=user_path,
                dictionaries=PIME_DICTIONARIES)
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

            reopened = ChewingContext(
                syspath=PIME_SEARCH_PATH,
                userpath=user_path,
                dictionaries=PIME_DICTIONARIES)
            try:
                self.assertEqual(reopened.userphrase_enumerate(), 0)
                phrase_len = c_uint()
                bopomofo_len = c_uint()
                persisted = []
                while reopened.userphrase_has_next(
                        byref(phrase_len),
                        byref(bopomofo_len)):
                    phrase_buffer = create_string_buffer(phrase_len.value)
                    bopomofo_buffer = create_string_buffer(
                        bopomofo_len.value)
                    self.assertEqual(
                        reopened.userphrase_get(
                            phrase_buffer,
                            phrase_len,
                            bopomofo_buffer,
                            bopomofo_len),
                        0)
                    persisted.append((
                        phrase_buffer.value.decode("utf-8"),
                        bopomofo_buffer.value.decode("utf-8")))
                self.assertIn((phrase, bopomofo), persisted)
            finally:
                reopened.close()

    def test_legacy_user_dictionary_is_backed_up_before_migration(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            user_path = os.path.join(temp_dir, "chewing.sqlite3")
            backup_path = user_path + ".pre-v0.13.1.bak"
            _create_legacy_user_dictionary(user_path)

            context = ChewingContext(
                syspath=PIME_SEARCH_PATH,
                userpath=user_path,
                dictionaries=PIME_DICTIONARIES)
            context.close()

            self.assertTrue(os.path.isfile(backup_path))
            with closing(sqlite3.connect(backup_path)) as backup:
                self.assertEqual(
                    backup.execute(
                        "SELECT phrase FROM userphrase_v1").fetchall(),
                    [("測試",)])
            with closing(sqlite3.connect(user_path)) as migrated:
                self.assertEqual(
                    migrated.execute(
                        "SELECT phrase FROM dictionary_v1").fetchall(),
                    [("測試",)])
                self.assertEqual(
                    migrated.execute(
                        "SELECT name FROM migration_v1").fetchall(),
                    [("migrate_from_userphrase_v1",)])

            with open(backup_path, "rb") as backup:
                original_backup = backup.read()
            reopened = ChewingContext(
                syspath=PIME_SEARCH_PATH,
                userpath=user_path,
                dictionaries=PIME_DICTIONARIES)
            reopened.close()
            with open(backup_path, "rb") as backup:
                self.assertEqual(backup.read(), original_backup)

    def test_selected_migrated_candidate_becomes_next_default(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            user_path = os.path.join(temp_dir, "chewing.sqlite3")
            _create_legacy_candidate_dictionary(user_path)

            context = ChewingContext(
                syspath=PIME_SEARCH_PATH,
                userpath=user_path,
                dictionaries=PIME_DICTIONARIES)
            try:
                context.set_autoLearn(0)
                context.set_KBType(0)
                context.set_candPerPage(10)
                context.set_spaceAsSelection(1)
                for key in "su3":
                    self.assertEqual(context.handle_Default(ord(key)), 0)
                self.assertEqual(
                    context.buffer_String().decode("utf-8"),
                    "你")

                context.handle_Space()
                context.cand_Enumerate()
                candidates = []
                while context.cand_hasNext():
                    candidates.append(
                        context.cand_String().decode("utf-8"))
                selected_index = candidates.index("妳")
                selection_keys = "1234567890"
                context.handle_Default(
                    ord(selection_keys[selected_index]))
                self.assertEqual(
                    context.buffer_String().decode("utf-8"),
                    "妳")
                context.handle_Enter()
                self.assertEqual(
                    context.commit_String().decode("utf-8"),
                    "妳")
            finally:
                context.close()

            reopened = ChewingContext(
                syspath=PIME_SEARCH_PATH,
                userpath=user_path,
                dictionaries=PIME_DICTIONARIES)
            try:
                for key in "su3":
                    self.assertEqual(reopened.handle_Default(ord(key)), 0)
                self.assertEqual(
                    reopened.buffer_String().decode("utf-8"),
                    "妳")
            finally:
                reopened.close()

    def test_remove_userphrases_by_phrase_persists(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            user_path = os.path.join(temp_dir, "chewing.sqlite3")
            phrase = "測試詞"
            bopomofo = "ㄘㄜˋ ㄕˋ ㄘˊ"
            context = ChewingContext(
                syspath=PIME_SEARCH_PATH,
                userpath=user_path,
                dictionaries=PIME_DICTIONARIES)
            try:
                self.assertEqual(
                    context.userphrase_add(
                        phrase.encode("utf-8"),
                        bopomofo.encode("utf-8")),
                    1)
            finally:
                context.close()

            context = ChewingContext(
                syspath=PIME_SEARCH_PATH,
                userpath=user_path,
                dictionaries=PIME_DICTIONARIES)
            try:
                self.assertEqual(
                    context.remove_userphrases_by_phrase(phrase),
                    1)
            finally:
                context.close()

            context = ChewingContext(
                syspath=PIME_SEARCH_PATH,
                userpath=user_path,
                dictionaries=PIME_DICTIONARIES)
            try:
                self.assertEqual(context.userphrase_enumerate(), 0)
                phrase_len = c_uint()
                bopomofo_len = c_uint()
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
                    self.assertNotEqual(
                        phrase_buffer.value.decode("utf-8"),
                        phrase)
            finally:
                context.close()

    def test_existing_invalid_backup_stops_legacy_migration(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            user_path = os.path.join(temp_dir, "chewing.sqlite3")
            backup_path = user_path + ".pre-v0.13.1.bak"
            _create_legacy_user_dictionary(user_path)
            with open(backup_path, "wb") as backup:
                backup.write(b"not a SQLite database")

            with self.assertRaisesRegex(
                    RuntimeError,
                    "Unable to verify the legacy libchewing user dictionary"):
                ChewingContext(
                    syspath=PIME_SEARCH_PATH,
                    userpath=user_path,
                    dictionaries=PIME_DICTIONARIES)

            with closing(sqlite3.connect(user_path)) as legacy:
                self.assertFalse(
                    legacy.execute(
                        "SELECT EXISTS ("
                        "SELECT 1 FROM sqlite_master "
                        "WHERE type='table' AND name='migration_v1'"
                        ")").fetchone()[0])

    def test_two_contexts_preserve_committed_userphrases(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            user_path = os.path.join(temp_dir, "chewing.sqlite3")
            first = ChewingContext(
                syspath=PIME_SEARCH_PATH,
                userpath=user_path,
                dictionaries=PIME_DICTIONARIES)
            second = ChewingContext(
                syspath=PIME_SEARCH_PATH,
                userpath=user_path,
                dictionaries=PIME_DICTIONARIES)
            try:
                self.assertEqual(
                    first.userphrase_add(
                        "測試詞".encode("utf-8"),
                        "ㄘㄜˋ ㄕˋ ㄘˊ".encode("utf-8")),
                    1)
                self.assertEqual(
                    second.userphrase_add(
                        "使用者".encode("utf-8"),
                        "ㄕˇ ㄩㄥˋ ㄓㄜˇ".encode("utf-8")),
                    1)
            finally:
                first.close()
                second.close()

            reopened = ChewingContext(
                syspath=PIME_SEARCH_PATH,
                userpath=user_path,
                dictionaries=PIME_DICTIONARIES)
            try:
                self.assertEqual(
                    _get_userphrases(reopened),
                    {
                        ("測試詞", "ㄘㄜˋ ㄕˋ ㄘˊ"),
                        ("使用者", "ㄕˇ ㄩㄥˋ ㄓㄜˇ"),
                    })
            finally:
                reopened.close()

    def test_pime_extension_dictionary_is_loaded(self):
        dictionary_dir = CHEWING_DICTIONARY_DIR
        for dictionary in ("pime.dat", "pime-ai.dat"):
            self.assertTrue(os.path.isfile(
                os.path.join(dictionary_dir, dictionary)))

        with tempfile.TemporaryDirectory() as temp_dir:
            cases = (
                ("a83n dk4", "馬斯克", "pime.dat"),
                ("u xj/6a83n dk4", "伊隆馬斯克", "pime-ai.dat"),
            )
            for index, (keys, phrase, extension) in enumerate(cases):
                with self.subTest(phrase=phrase):
                    context = ChewingContext(
                        syspath=";".join((
                            dictionary_dir, CHEWING_DATA_DIR)),
                        userpath=os.path.join(
                            temp_dir, "user-{}.sqlite3".format(index)),
                        dictionaries=("word.dat", "tsi.dat", extension))
                    try:
                        for key in keys:
                            self.assertEqual(
                                context.handle_Default(ord(key)), 0)
                        for _ in phrase:
                            context.handle_Left()
                        context.handle_Down()
                        context.cand_Enumerate()
                        candidates = []
                        while context.cand_hasNext():
                            candidates.append(
                                context.cand_String().decode("utf-8"))
                        self.assertIn(phrase, candidates)
                    finally:
                        context.close()


if __name__ == "__main__":
    unittest.main()
