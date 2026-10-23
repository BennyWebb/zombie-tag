"""Makes the Godot version's two extra fonts, cut down to just the characters the game uses:

- godot/fonts/emoji.ttf: Noto Color Emoji, for the shop icons, the gym and messages. The whole
  font is 25 MB; the game uses a few dozen emoji. (It keeps the font's SVG pictures, which Godot
  draws, and drops its COLR ones, which Godot can't.)
- godot/fonts/symbols.ttf: Noto Sans Symbols 2, for the arrows, triangles and tick that Fredoka
  doesn't have (SYMBOLS below).

It finds the emoji in the browser game's code and the Godot scripts, so run it again after adding
new emoji or symbols:

    pip install fonttools
    python tools/subset-fonts.py NotoColorEmoji-Regular.ttf NotoSansSymbols2-Regular.ttf

Both are in https://github.com/google/fonts (ofl/notocoloremoji and ofl/notosanssymbols2).
"""

import glob
import sys
from pathlib import Path

from fontTools import subset

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ["src/*.js", "index.html", "godot/scripts/*.gd"]
# plain symbols, drawn in the text's own colour (the rest come in colour from the emoji font)
SYMBOLS = "▲▼◀▶✔★➜🡐🡒🡑🡓⌫▮▯"


def is_emoji(ch):
    c = ord(ch)
    return (
        c >= 0x1F000  # most emoji
        or 0x2600 <= c <= 0x27BF  # symbols and dingbats, like ❤ ✨
        or 0x2B00 <= c <= 0x2BFF  # stars, like ⭐
        or 0x2300 <= c <= 0x23FF  # like ⏱
        or 0x2190 <= c <= 0x21FF  # arrows, like ↩
        or c in (0x200D, 0xFE0F)  # the joiners that build emoji like 🏴‍☠️ and 🧑‍🚀
    )


def make(source, out, chars, options):
    font = subset.load_font(source, options)
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=[ord(ch) for ch in chars])
    subsetter.subset(font)
    font.save(out)
    print(f"{len(chars)} characters -> {out} ({out.stat().st_size // 1024} KB)")


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    found = set()
    for pattern in SOURCES:
        for path in glob.glob(str(ROOT / pattern)):
            found.update(ch for ch in Path(path).read_text(encoding="utf-8") if is_emoji(ch))
    emoji = sorted(found - set(SYMBOLS))
    options = subset.Options()
    options.layout_features = ["*"]  # keeps the rules that join emoji like 🏴‍☠️ together
    options.drop_tables += ["COLR", "CPAL"]
    make(sys.argv[1], ROOT / "godot/fonts/emoji.ttf", emoji, options)
    make(sys.argv[2], ROOT / "godot/fonts/symbols.ttf", SYMBOLS, subset.Options())


main()
