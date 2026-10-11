# Read a page diffview rendered: the data it embeds. Sourced by the diffview tests.

# a Python expression over a page's data: data is all of it, f the file at path (None for an empty path),
# baked(side) the sha256 of that image version as baked, "none" when the card has no such version,
# "unbaked SIZE" when it was left out
field() {
    python3 - "$@" <<'EOF'
import base64, hashlib, json, sys
page, path, expr = sys.argv[1:]
text = open(page).read()
data, _ = json.JSONDecoder().raw_decode(text, text.index("const DATA = ") + len("const DATA = "))
f = next((f for s in data["sources"] for f in s["files"] if f["path"] == path), None)
def baked(side):
    v = (f.get("image") or {}).get(side)
    return "none" if v is None else hashlib.sha256(base64.b64decode(v["src"].split(",", 1)[1])).hexdigest() if "src" in v else f"unbaked {v['size']}"
print(eval(expr))
EOF
}
datum() { field "$1" "" "$2"; }   # page, then an expression over its data alone
paths() { datum "$1" "' | '.join(f['path'] for s in data['sources'] for f in s['files'])"; }
added() { field "$1" "$2" "[ln[3] for h in f['hunks'] for ln in h['lines'] if ln[0] == 1]"; }   # page, path: its added lines
saved() { datum "$1" "[c['text'] for c in data['saved']['comments']]"; }   # page: the texts of the comments baked into it
