#
# Copyright (C) libchewing developers
# Updated with assistance from OpenAI GPT-5.6.
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

from ctypes import CDLL, POINTER, c_char, c_char_p, c_int, c_uint, c_void_p
import os
import sys
from typing import Any

_libchewing: Any = None
if sys.platform == "win32": # Windows
    # find in current dir first
    dll_path = os.path.join(os.path.dirname(__file__), "chewing.dll")
    if not os.path.exists(dll_path):
        dll_path = "chewing.dll" # search in system path
    _libchewing = CDLL(dll_path)
else: # UNIX-like systems
    _libchewing = CDLL('libchewing.so.3')

_context_pointer = c_void_p


def _declare(name, argtypes, restype: Any = c_int):
    """Declare one libchewing C ABI function used by PIME."""
    function = getattr(_libchewing, name)
    function.argtypes = argtypes
    function.restype = restype


_declare("chewing_Init", [c_char_p, c_char_p])
_declare("chewing_new", [], _context_pointer)
_declare(
    "chewing_new2",
    [c_char_p, c_char_p, c_void_p, c_void_p],
    _context_pointer)
_declare(
    "chewing_new3",
    [c_char_p, c_char_p, c_char_p, c_void_p, c_void_p],
    _context_pointer)
_declare("chewing_delete", [_context_pointer], None)
_declare("chewing_version", [], c_char_p)

for _name in (
        "commit_String_static",
        "buffer_String_static",
        "cand_String_static",
        "bopomofo_String_static",
        "aux_String_static",
        "kbtype_String_static"):
    _declare("chewing_" + _name, [_context_pointer], c_char_p)

for _name in (
        "set_addPhraseDirection",
        "set_autoShiftCur",
        "set_candPerPage",
        "set_escCleanAllBuf",
        "set_spaceAsSelection",
        "set_autoLearn",
        "set_phraseChoiceRearward",
        "set_maxChiSymbolLen",
        "set_ChiEngMode",
        "set_ShapeMode",
        "set_easySymbolInput"):
    _declare("chewing_" + _name, [_context_pointer, c_int], None)

_declare("chewing_set_KBType", [_context_pointer, c_int])
_declare(
    "chewing_set_selKey",
    [_context_pointer, POINTER(c_int), c_int],
    None)

for _name in (
        "get_ChiEngMode",
        "get_ShapeMode",
        "get_easySymbolInput",
        "cand_TotalChoice",
        "cand_TotalPage",
        "cand_ChoicePerPage",
        "cand_hasNext",
        "cand_close",
        "keystroke_CheckIgnore",
        "commit_Check",
        "buffer_Check",
        "bopomofo_Check",
        "cursor_Current",
        "aux_Check",
        "clean_bopomofo_buf",
        "commit_preedit_buf"):
    _declare("chewing_" + _name, [_context_pointer])

_declare("chewing_cand_Enumerate", [_context_pointer], None)

for _name in (
        "handle_Default",
        "handle_CtrlNum",
        "handle_Numlock"):
    _declare("chewing_" + _name, [_context_pointer, c_int])

for _name in (
        "handle_Space",
        "handle_PageUp",
        "handle_PageDown",
        "handle_Down",
        "handle_Left",
        "handle_Right",
        "handle_Esc",
        "handle_Enter",
        "handle_Tab",
        "handle_Del",
        "handle_Backspace",
        "handle_Up",
        "handle_Home",
        "handle_End"):
    _declare("chewing_" + _name, [_context_pointer])

_declare("chewing_userphrase_enumerate", [_context_pointer])
_declare(
    "chewing_userphrase_has_next",
    [_context_pointer, POINTER(c_uint), POINTER(c_uint)])
_declare(
    "chewing_userphrase_get",
    [_context_pointer, POINTER(c_char), c_uint, POINTER(c_char), c_uint])
for _name in ("userphrase_add", "userphrase_remove"):
    _declare(
        "chewing_" + _name,
        [_context_pointer, c_char_p, c_char_p])


def _encode_path(path):
    if path is None or isinstance(path, bytes):
        return path
    return os.fsencode(path)


def Init(datadir, userdir):
    return _libchewing.chewing_Init(
        _encode_path(datadir),
        _encode_path(userdir))


class ChewingContext:
    """Own a native context, optionally with an explicit dictionary list."""

    def __init__(self, **kwargs):
        if not kwargs:
            self.ctx = _libchewing.chewing_new()
        else:
            syspath = _encode_path(kwargs.get("syspath", None))
            userpath = _encode_path(kwargs.get("userpath", None))
            dictionaries = kwargs.get("dictionaries", None)
            if dictionaries is None:
                self.ctx = _libchewing.chewing_new2(
                    syspath,
                    userpath,
                    None,
                    None)
            else:
                if not isinstance(dictionaries, (str, bytes)):
                    dictionaries = ",".join(dictionaries)
                self.ctx = _libchewing.chewing_new3(
                    syspath,
                    userpath,
                    _encode_path(dictionaries),
                    None,
                    None)
        if not self.ctx:
            raise RuntimeError("Unable to create a libchewing context")

    def __del__(self):
        try:
            self.close()
        except Exception:
            # Destructors must not leak exceptions during interpreter shutdown.
            pass

    def close(self):
        """Release the native context. Calling this method twice is safe."""
        ctx = getattr(self, "ctx", None)
        if ctx:
            _libchewing.chewing_delete(ctx)
            self.ctx = None

    def __getattr__(self, name):
        if name == "ctx":
            raise AttributeError(name)
        if not self.ctx:
            raise RuntimeError("The libchewing context is closed")
        func = 'chewing_' + name
        # force the use of the APIs returning const char* to avoid memory leaks
        if name.endswith("_String"):
            func += "_static"
        if func in _libchewing.__dict__:
            function = _libchewing.__dict__[func]
            wrap = self._bind(function)
            setattr(self, name, wrap)
            return wrap
        elif hasattr(_libchewing, func):
            function = _libchewing.__getattr__(func)
            wrap = self._bind(function)
            setattr(self, name, wrap)
            return wrap
        else:
            raise AttributeError(name)

    def _bind(self, function):
        def call(*args):
            if not self.ctx:
                raise RuntimeError("The libchewing context is closed")
            return function(self.ctx, *args)
        return call

    # The original libchewing API is set_selKey (without 's')
    # It only accepts an integer array. Let's create a new API that accepts
    # a python string
    def set_selKeys(self, selKeys):
        selKeyCodes = (c_int * len(selKeys))()
        for i, key in enumerate(selKeys):
            selKeyCodes[i] = ord(key)
        _libchewing.chewing_set_selKey(self.ctx, selKeyCodes, len(selKeys))

    def Configure(self, cpp, maxlen, direction, space, kbtype):
        self.set_candPerPage(cpp)
        self.set_maxChiSymbolLen(maxlen)
        self.set_addPhraseDirection(direction)
        self.set_spaceAsSelection(space)
        self.set_KBType(kbtype)
