import os

from .libchewing import ChewingContext

_current_dir = os.path.dirname(__file__)

CHEWING_DATA_DIR = os.path.join(_current_dir, "data")
CHEWING_DICTIONARY_DIR = os.path.join(CHEWING_DATA_DIR, "dictionary.d")
PIME_DICTIONARIES = (
    "word.dat",
    "tsi.dat",
    "pime.dat",
    "pime-ai.dat",
)

# from libchewing/include/global.h
CHINESE_MODE = 1
ENGLISH_MODE = 0
FULLSHAPE_MODE = 1
HALFSHAPE_MODE = 0
