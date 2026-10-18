# Generated with assistance from OpenAI GPT-5.6.

"""Safeguards for opening legacy libchewing user dictionaries."""

from contextlib import closing, contextmanager
import os
import sqlite3
import threading


BACKUP_SUFFIX = ".pre-v0.13.1.bak"
_MIGRATION_NAME = "migrate_from_userphrase_v1"


def _table_exists(connection, name):
    row = connection.execute(
        "SELECT EXISTS ("
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?"
        ")",
        (name,)).fetchone()
    return bool(row and row[0])


def _migration_completed(connection):
    if not _table_exists(connection, "migration_v1"):
        return False
    row = connection.execute(
        "SELECT EXISTS (SELECT 1 FROM migration_v1 WHERE name=?)",
        (_MIGRATION_NAME,)).fetchone()
    return bool(row and row[0])


def _verify_backup(path):
    try:
        with closing(sqlite3.connect(path)) as connection:
            result = connection.execute("PRAGMA quick_check").fetchone()
            has_legacy_table = _table_exists(
                connection, "userphrase_v1")
        if not result or result[0] != "ok":
            raise RuntimeError(
                "The legacy libchewing user dictionary backup is corrupt: "
                + path)
        if not has_legacy_table:
            raise RuntimeError(
                "The legacy libchewing user dictionary backup is invalid: "
                + path)
    except sqlite3.Error as error:
        raise RuntimeError(
            "Unable to verify the legacy libchewing user dictionary "
            "backup: " + path) from error


@contextmanager
def _migration_lock(path):
    """Serialize backup and native migration across PIME processes."""
    lock_file = open(path, "a+b")
    try:
        lock_file.seek(0, os.SEEK_END)
        if lock_file.tell() == 0:
            lock_file.write(b"\0")
            lock_file.flush()
        lock_file.seek(0)
        if os.name == "nt":
            import msvcrt
            msvcrt.locking(lock_file.fileno(), msvcrt.LK_LOCK, 1)
        else:
            import fcntl
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
        try:
            yield
        finally:
            lock_file.seek(0)
            if os.name == "nt":
                msvcrt.locking(lock_file.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
    finally:
        lock_file.close()


@contextmanager
def prepare_user_dictionary(path):
    """Back up an unmigrated v1 SQLite dictionary before native opening."""
    if path is None:
        yield
        return

    path = os.fsdecode(path)
    if path == ":memory:" or not os.path.isfile(path):
        yield
        return

    lock_path = path + ".migration.lock"
    with _migration_lock(lock_path):
        with closing(sqlite3.connect(path, timeout=30)) as source:
            needs_backup = (
                _table_exists(source, "userphrase_v1")
                and not _migration_completed(source))
            if needs_backup:
                backup_path = path + BACKUP_SUFFIX
                if os.path.exists(backup_path):
                    _verify_backup(backup_path)
                else:
                    temporary_path = "{}.tmp-{}-{}".format(
                        backup_path, os.getpid(), threading.get_ident())
                    try:
                        with closing(
                                sqlite3.connect(temporary_path)) as destination:
                            source.backup(destination)
                        _verify_backup(temporary_path)
                        os.replace(temporary_path, backup_path)
                    finally:
                        if os.path.exists(temporary_path):
                            os.remove(temporary_path)
        yield
