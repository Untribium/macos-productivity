#!/usr/bin/env python3
"""Turn the all-keyboards HiTilde layout into one that swaps 10<->50 on ISO only.

usage: gen_layout.py SRC.keylayout OUT.keylayout ISO_TYPES NAME ID

ISO_TYPES: comma-separated keyboard type IDs that macOS classifies as ISO
(KBGetLayoutType). Text edits only, so the diff against SRC stays readable.

Authoring-time only: the output is committed, install-layout.sh does not run
this. The committed US (ISO-safe).keylayout was made with:

  ISO=$(osascript -l JavaScript -e 'ObjC.import("Carbon"); const r=[];
    for (let t=0; t<256; t++) if ($.KBGetLayoutType(t)===0x49534F20) r.push(t);
    r.join(",")')
  python3 -I gen_layout.py "US ISO HiTilde.keylayout" "US (ISO-safe).keylayout" \
    "$ISO" "US (ISO-safe)" -28417

The name is also the input source ID (org.unknown.keylayout.USISO-safe), so
renaming means a new layout to enable, and a new consent prompt.
"""
import re
import sys

src, out, iso_arg, name, kid = sys.argv[1:6]
iso = sorted(int(t) for t in iso_arg.split(","))
text = open(src, encoding="utf-8").read()

# ---- 1. base map set back to stock US for keycodes 10 and 50 --------------
# HiTilde swapped them in maps 0 and 1 only; maps 2-7 are stock already.
STOCK = {"0": {"10": 'output="§"', "50": 'output="`"'},
         "1": {"10": 'output="±"', "50": 'output="~"'}}

base_start = text.index('<keyMapSet id="16c">')
base_end = text.index("</keyMapSet>", base_start)
base = text[base_start:base_end]

def fix_map(m):
    idx, body = m.group(1), m.group(2)
    for code, attr in STOCK.get(idx, {}).items():
        body, n = re.subn(rf'<key code="{code}" [^/]*/>', f'<key code="{code}" {attr}/>', body)
        assert n == 1, (idx, code)
    return f'<keyMap index="{idx}">{body}</keyMap>'

base = re.sub(r'<keyMap index="(\d)">(.*?)</keyMap>', fix_map, base, flags=re.S)
text = text[:base_start] + base + text[base_end:]

# ---- 2. ISO map set: base with 10 and 50 swapped, in every modifier map ----
iso_maps = []
for m in re.finditer(r'<keyMap index="(\d)">(.*?)</keyMap>', base, flags=re.S):
    idx, body = m.group(1), m.group(2)
    attr = {c: re.search(rf'<key code="{c}" ([^/]*)/>', body).group(1) for c in ("10", "50")}
    iso_maps.append(
        f'\t\t<keyMap index="{idx}" baseMapSet="16c" baseIndex="{idx}">\n'
        f'\t\t\t<key code="10" {attr["50"]}/>\n'
        f'\t\t\t<key code="50" {attr["10"]}/>\n'
        f"\t\t</keyMap>\n")
iso_set = '\t<keyMapSet id="iso">\n' + "".join(iso_maps) + "\t</keyMapSet>\n"
actions_at = text.index("\t<actions>")
text = text[:actions_at] + iso_set + text[actions_at:]

# ---- 3. layouts: every type 0-255 explicit, no reliance on fallback --------
jis = set()
for m in re.finditer(r'<layout first="(\d+)" last="(\d+)" mapSet="984"', text):
    jis.update(range(int(m.group(1)), int(m.group(2)) + 1))

def mapset(t):
    return "iso" if t in iso else "984" if t in jis else "16c"

ranges = []
for t in range(256):
    ms = mapset(t)
    if ranges and ranges[-1][2] == ms and ranges[-1][1] == t - 1:
        ranges[-1][1] = t
    else:
        ranges.append([t, t, ms])
layouts = "".join(f'\t\t<layout first="{a}" last="{b}" mapSet="{ms}" modifiers="f4"/>\n'
                  for a, b, ms in ranges)
text = re.sub(r"\t\t<layout .*?</layouts>", layouts + "\t</layouts>", text, flags=re.S)

# ---- 4. identity -------------------------------------------------------------
text = re.sub(r'<keyboard group="126" id="-?\d+" name="[^"]*"',
              f'<keyboard group="126" id="{kid}" name="{name}"', text)
text = re.sub(r"<!--Last edited by Ukelele.*?-->",
              "<!--Generated from US ISO HiTilde (Ukelele 3.2.7, 2019): "
              "keycodes 10/50 swapped on ISO keyboard types only-->", text)

open(out, "w", encoding="utf-8").write(text)
print(f"{len(ranges)} layout ranges, {len(iso)} ISO types -> {out}")
