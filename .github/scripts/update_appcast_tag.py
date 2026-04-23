"""
Generates an arch-specific Sparkle appcast XML for a tagged GenQuery release.

Usage:
    python3 update_appcast_tag.py <arch>   # arch = arm64 | x86_64

Reads:
    sign_update_<arch>.txt   - output of Sparkle's sign_update tool
    appcast_<arch>.xml       - existing appcast (created if absent)

Writes:
    appcast_<arch>_new.xml   - updated appcast (rename to appcast_<arch>.xml)

Required environment variables:
    GENQ_VERSION        Version tag, e.g. v0.1.2
    GENQ_BUILD          Monotonically increasing integer (use Unix timestamp in CI)
    GENQ_COMMIT         Short commit hash
    GENQ_COMMIT_LONG    Full commit hash
"""

import os
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

REPO = "https://github.com/miams/genq"
GH_RELEASES = f"{REPO}/releases"
PRUNE_AMOUNT = 15
PUBDATE_FORMAT = "%a, %d %b %Y %H:%M:%S %z"
EMPTY_APPCAST = """\
<?xml version='1.0' encoding='utf-8'?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>GenQuery</title>
    <link>{}</link>
    <description>GenQuery auto-update feed</description>
    <language>en</language>
  </channel>
</rss>
"""

if len(sys.argv) != 2 or sys.argv[1] not in ("arm64", "x86_64"):
    print("Usage: update_appcast_tag.py <arm64|x86_64>", file=sys.stderr)
    sys.exit(1)

arch = sys.argv[1]

now         = datetime.now(timezone.utc)
version     = os.environ["GENQ_VERSION"]          # e.g. v0.1.2
build       = os.environ["GENQ_BUILD"]             # monotonically increasing int
commit      = os.environ["GENQ_COMMIT"]            # short hash
commit_long = os.environ["GENQ_COMMIT_LONG"]       # full hash

# Strip leading 'v' for display, keep full tag for URLs.
version_display = version.lstrip("v")

# --- Read Sparkle EdDSA signature output ----------------------------------- #
with open(f"sign_update_{arch}.txt", "r") as f:
    attrs = {}
    for pair in f.read().strip().split(" "):
        key, value = pair.split("=", 1)
        value = value.strip()
        if value.startswith('"'):
            value = value[1:-1]
        attrs[key] = value

# --- Register namespaces before any parse/write ---------------------------- #
SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
namespaces = {"sparkle": SPARKLE_NS}
for prefix, uri in namespaces.items():
    ET.register_namespace(prefix, uri)

def sparkle(tag):
    """Return Clark-notation tag for a sparkle: element, e.g. sparkle('version')."""
    return f"{{{SPARKLE_NS}}}{tag}"

# --- Load or create the existing appcast ----------------------------------- #
appcast_file = f"appcast_{arch}.xml"
if not os.path.exists(appcast_file):
    with open(appcast_file, "w") as f:
        f.write(EMPTY_APPCAST.format(GH_RELEASES))

et = ET.parse(appcast_file)
channel = et.find("channel")

# Remove duplicate build entries and items without pubDate.
for item in list(channel.findall("item")):
    sv = item.find(sparkle("version"))
    if sv is not None and sv.text == build:
        channel.remove(item)
    elif item.find("pubDate") is None:
        channel.remove(item)

# Prune oldest items beyond the limit.
items = channel.findall("item")
items.sort(key=lambda i: datetime.strptime(i.find("pubDate").text, PUBDATE_FORMAT))
for item in items[:-PRUNE_AMOUNT]:
    channel.remove(item)

# --- Build the new item ---------------------------------------------------- #
dmg_url = (
    f"{GH_RELEASES}/download/{version}"
    f"/GenQuery-Terminal-macOS-{arch}.dmg"
)

item = ET.SubElement(channel, "item")

ET.SubElement(item, "title").text           = f"GenQuery {version_display}"
ET.SubElement(item, "pubDate").text         = now.strftime(PUBDATE_FORMAT)

sv = ET.SubElement(item, sparkle("version"))
sv.text = build

svs = ET.SubElement(item, sparkle("shortVersionString"))
svs.text = version_display

msv = ET.SubElement(item, sparkle("minimumSystemVersion"))
msv.text = "13.0.0"

rnl = ET.SubElement(item, sparkle("fullReleaseNotesLink"))
rnl.text = f"{GH_RELEASES}/tag/{version}"

desc = ET.SubElement(item, "description")
desc.text = (
    f"<h1>GenQuery {version_display}</h1>"
    f"<p>Built from commit "
    f'<code><a href="{REPO}/commits/{commit_long}">{commit}</a></code> '
    f"on {now.strftime('%Y-%m-%d')}.</p>"
    f'<p>See the <a href="{GH_RELEASES}/tag/{version}">release page</a> '
    f"for full release notes.</p>"
)

enclosure = ET.SubElement(item, "enclosure")
enclosure.set("url", dmg_url)
enclosure.set("type", "application/octet-stream")
for key, value in attrs.items():
    enclosure.set(key, value)

# --- Write output ---------------------------------------------------------- #
out_file = f"appcast_{arch}_new.xml"
et.write(out_file, xml_declaration=True, encoding="utf-8")
print(f"Written {out_file}  (arch={arch}, version={version_display}, build={build})")
