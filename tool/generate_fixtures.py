#!/usr/bin/env python3
"""Generates the synthetic PDF test corpus in fixtures/pdf/.

Each file targets one structure the suite must either handle or reject with a
typed exception. fixtures/pdf/manifest.json records, per file, what it is and
what PdfPreflight is expected to report, so Dart tests can check every file.

Requirements: Python 3.10+, `pip install reportlab pypdf pikepdf pillow`, and
the `qpdf` command-line tool.

Usage, from the repository root:
    python3 tool/generate_fixtures.py

Output is deterministic apart from timestamps and IDs embedded by the
libraries, so regenerate only when the corpus itself needs to change.
"""

from __future__ import annotations

import io
import json
import shutil
import subprocess
import zlib
from pathlib import Path

from PIL import Image
from pypdf import PdfReader, PdfWriter
from reportlab.lib.colors import black, lightgrey
from reportlab.lib.pagesizes import A4, landscape, letter
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "fixtures" / "pdf"

MANIFEST: list[dict] = []


def record(name: str, description: str, expect: dict, tool: str) -> None:
    """Adds a manifest entry. `expect` lists PdfPreflight fields to check."""
    MANIFEST.append(
        {"file": name, "description": description, "generatedWith": tool, "expect": expect}
    )


def classic(**overrides) -> dict:
    """Expected preflight values for a plain, classic, unencrypted PDF."""
    values = {
        "isPdf": True,
        "isEncrypted": False,
        "usesObjectStreams": False,
        "usesCrossReferenceStreams": False,
        "hasClassicTrailer": True,
        "hasXfa": False,
        "isReadable": True,
        "isIncrementallyWritable": True,
    }
    values.update(overrides)
    return values


def qpdf(*args: str) -> None:
    subprocess.run(["qpdf", *args], check=True)


# --------------------------------------------------------------------------
# Plain documents
# --------------------------------------------------------------------------


def text_pdf(path: Path, pages: int = 1, pagesize=A4, title="Sample") -> None:
    c = canvas.Canvas(str(path), pagesize=pagesize, pageCompression=0)
    c.setTitle(title)
    width, height = pagesize
    for page in range(pages):
        c.setFont("Helvetica-Bold", 18)
        c.drawString(72, height - 72, f"{title} - page {page + 1} of {pages}")
        c.setFont("Helvetica", 11)
        for line in range(20):
            c.drawString(72, height - 110 - line * 16, f"Line {line + 1}: The quick brown fox jumps over the lazy dog.")
        c.showPage()
    c.save()


def build_plain() -> None:
    text_pdf(OUT / "text_single_page.pdf", title="Single page")
    record("text_single_page.pdf", "One A4 page of Helvetica text, uncompressed streams.", classic(), "reportlab")

    text_pdf(OUT / "text_multi_page.pdf", pages=12, title="Multi page")
    record("text_multi_page.pdf", "Twelve A4 pages of text.", classic(), "reportlab")

    text_pdf(OUT / "text_letter_landscape.pdf", pagesize=landscape(letter), title="Letter landscape")
    record("text_letter_landscape.pdf", "US Letter page in landscape orientation.", classic(), "reportlab")

    # Mixed page sizes.
    c = canvas.Canvas(str(OUT / "mixed_page_sizes.pdf"), pageCompression=0)
    for size in (A4, letter, landscape(A4), (300, 300)):
        c.setPageSize(size)
        c.drawString(40, size[1] - 60, f"Page size {size[0]:.0f} x {size[1]:.0f} pt")
        c.showPage()
    c.save()
    record("mixed_page_sizes.pdf", "Four pages: A4, Letter, A4 landscape and a 300 pt square.", classic(), "reportlab")

    # Rotated pages via /Rotate.
    reader = PdfReader(str(OUT / "text_multi_page.pdf"))
    writer = PdfWriter()
    for index, page in enumerate(reader.pages[:4]):
        page.rotate(90 * index)
        writer.add_page(page)
    with open(OUT / "rotated_pages.pdf", "wb") as handle:
        writer.write(handle)
    record("rotated_pages.pdf", "Four pages with /Rotate 0, 90, 180 and 270.", classic(), "pypdf")

    # Unicode text with an embedded TrueType font (CID font, /ToUnicode).
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont

    pdfmetrics.registerFont(TTFont("DejaVuSans", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"))
    c = canvas.Canvas(str(OUT / "unicode_embedded_font.pdf"), pagesize=A4)
    c.setFont("DejaVuSans", 14)
    for row, sample in enumerate(["Café, naïve, Zürich, São Paulo", "Ελληνικά — Русский — Čeština", "€ £ ¥ © ® ™ ½ ¼ → ←"]):
        c.drawString(72, 760 - row * 24, sample)
    c.save()
    record("unicode_embedded_font.pdf", "Accented Latin, Greek and Cyrillic text in an embedded DejaVu Sans subset.", classic(), "reportlab")

    # Images: JPEG and PNG with transparency.
    gradient = Image.linear_gradient("L").resize((256, 256)).convert("RGB")
    jpeg = io.BytesIO()
    gradient.save(jpeg, "JPEG", quality=80)
    rgba = Image.new("RGBA", (128, 128), (30, 120, 220, 0))
    for x in range(128):
        for y in range(128):
            if (x - 64) ** 2 + (y - 64) ** 2 < 50 ** 2:
                rgba.putpixel((x, y), (30, 120, 220, 255))
    png = io.BytesIO()
    rgba.save(png, "PNG")
    c = canvas.Canvas(str(OUT / "images_jpeg_png.pdf"), pagesize=A4)
    c.drawImage(ImageReader(io.BytesIO(jpeg.getvalue())), 72, 500, 200, 200)
    c.drawImage(ImageReader(io.BytesIO(png.getvalue())), 320, 500, 128, 128, mask="auto")
    c.drawString(72, 470, "JPEG (DCTDecode) on the left, PNG with alpha (SMask) on the right.")
    c.save()
    record("images_jpeg_png.pdf", "A JPEG image and a PNG image with an alpha mask.", classic(), "reportlab + pillow")

    c = canvas.Canvas(str(OUT / "blank_page.pdf"), pagesize=A4, pageCompression=0)
    c.showPage()
    c.save()
    record("blank_page.pdf", "A single empty A4 page.", classic(), "reportlab")


# --------------------------------------------------------------------------
# AcroForms
# --------------------------------------------------------------------------


def build_forms() -> None:
    path = OUT / "form_classic.pdf"
    c = canvas.Canvas(str(path), pagesize=A4, pageCompression=0)
    form = c.acroForm
    c.setFont("Helvetica", 12)
    c.drawString(72, 770, "Name")
    form.textfield(name="full_name", x=180, y=760, width=250, height=22, value="", borderColor=black, fillColor=lightgrey)
    c.drawString(72, 730, "Email")
    form.textfield(name="email", x=180, y=720, width=250, height=22, value="", borderColor=black, fillColor=lightgrey)
    c.drawString(72, 690, "Accept terms")
    form.checkbox(name="accept_terms", x=180, y=685, size=18, checked=False, buttonStyle="check")
    c.drawString(72, 650, "Contact by")
    form.radio(name="contact_method", value="email", selected=True, x=180, y=645, size=16)
    form.radio(name="contact_method", value="phone", selected=False, x=240, y=645, size=16)
    c.drawString(72, 610, "Country")
    form.choice(name="country", value="Saudi Arabia", options=["Saudi Arabia", "Bangladesh", "India"], x=180, y=600, width=200, height=22)
    c.drawString(72, 570, "Skills")
    form.listbox(name="skills", value="Dart", options=["Dart", "Flutter", "PDF"], x=180, y=520, width=200, height=60)
    c.save()
    record(
        "form_classic.pdf",
        "AcroForm with text, checkbox, radio group, combo box and list box fields; classic xref.",
        classic(hasAcroForm=True),
        "reportlab",
    )

    # Filled values, full rewrite.
    reader = PdfReader(str(path))
    writer = PdfWriter()
    writer.append(reader)
    writer.update_page_form_field_values(writer.pages[0], {"full_name": "Sakibul Haque", "email": "dev@example.com"}, auto_regenerate=False)
    with open(OUT / "form_filled.pdf", "wb") as handle:
        writer.write(handle)
    record("form_filled.pdf", "form_classic.pdf with text values filled and the file rewritten.", classic(hasAcroForm=True), "pypdf")

    # Classic incremental update: changed object + classic xref section + /Prev.
    append_classic_update(path, OUT / "form_incremental_update.pdf", "full_name", "Incremental Value")
    record(
        "form_incremental_update.pdf",
        "form_classic.pdf with full_name changed in an appended classic incremental update (two %%EOF markers).",
        classic(hasAcroForm=True, revisionCount=2),
        "hand-written incremental update",
    )

    # Hybrid: classic original + an update whose xref is a stream (pypdf does this).
    writer = PdfWriter(str(path), incremental=True)
    writer.update_page_form_field_values(writer.pages[0], {"full_name": "Incremental Value"}, auto_regenerate=False)
    with open(OUT / "form_incremental_xref_stream.pdf", "wb") as handle:
        writer.write(handle)
    record(
        "form_incremental_xref_stream.pdf",
        "form_classic.pdf updated incrementally by pypdf: classic first revision, cross-reference stream in the second.",
        classic(hasAcroForm=True, revisionCount=2, usesCrossReferenceStreams=True, isIncrementallyWritable=False),
        "pypdf (incremental)",
    )

    # Compressed object streams + xref stream: what Acrobat and Word typically write.
    qpdf("--object-streams=generate", "--compress-streams=y", str(path), str(OUT / "form_object_streams.pdf"))
    record(
        "form_object_streams.pdf",
        "form_classic.pdf rewritten with compressed object streams and a cross-reference stream (PDF 1.5+ layout).",
        classic(usesObjectStreams=True, usesCrossReferenceStreams=True, hasClassicTrailer=False, isReadable=False, isIncrementallyWritable=False),
        "qpdf --object-streams=generate",
    )

    write_raw_pdf(OUT / "form_hierarchical_names.pdf", hierarchical_form_objects())
    record(
        "form_hierarchical_names.pdf",
        "Hand-written AcroForm where person.name and person.email inherit /FT and /DA from a parent field.",
        classic(hasAcroForm=True),
        "hand-written (tool/generate_fixtures.py)",
    )

    write_raw_pdf(OUT / "form_xfa_only.pdf", xfa_only_objects())
    record(
        "form_xfa_only.pdf",
        "Hand-written XFA form: /AcroForm has an /XFA stream and an empty /Fields array.",
        classic(hasAcroForm=True, hasXfa=True),
        "hand-written (tool/generate_fixtures.py)",
    )


def append_classic_update(source: Path, target: Path, field: str, value: str) -> None:
    """Appends a classic incremental update that sets /V of the named text field."""
    import re

    data = source.read_bytes()
    text = data.decode("latin1")
    match = next(
        m for m in re.finditer(r"(\d+) 0 obj\s*(.*?)endobj", text, re.S) if f"/T ({field})" in m.group(2)
    )
    number = int(match.group(1))
    body = re.sub(r"/V \([^)]*\)", f"/V ({value})", match.group(2).strip())
    trailer = re.findall(r"trailer\s*<<(.*?)>>\s*startxref\s+(\d+)", text, re.S)[-1]
    size = re.search(r"/Size\s+(\d+)", trailer[0]).group(1)
    root = re.search(r"/Root\s+(\d+ \d+ R)", trailer[0]).group(1)
    out = bytearray(data if data.endswith(b"\n") else data + b"\n")
    offset = len(out)
    out += f"{number} 0 obj\n{body}\nendobj\n".encode("latin1")
    xref = len(out)
    out += f"xref\n{number} 1\n{offset:010d} 00000 n \n".encode()
    out += f"trailer\n<< /Size {size} /Root {root} /Prev {trailer[1]} >>\nstartxref\n{xref}\n%%EOF\n".encode()
    target.write_bytes(bytes(out))


def write_raw_pdf(path: Path, objects: list[bytes]) -> None:
    """Writes objects 1..n with a correct classic xref table. Object 1 is the catalog."""
    out = bytearray(b"%PDF-1.7\n%\xe2\xe3\xcf\xd3\n")
    offsets = []
    for number, body in enumerate(objects, start=1):
        offsets.append(len(out))
        out += f"{number} 0 obj\n".encode() + body + b"\nendobj\n"
    xref = len(out)
    out += f"xref\n0 {len(objects) + 1}\n0000000000 65535 f \n".encode()
    for offset in offsets:
        out += f"{offset:010d} 00000 n \n".encode()
    out += f"trailer\n<< /Root 1 0 R /Size {len(objects) + 1} >>\nstartxref\n{xref}\n%%EOF\n".encode()
    path.write_bytes(bytes(out))


def stream(data: bytes, extra: str = "") -> bytes:
    return f"<< /Length {len(data)} {extra}>>\nstream\n".encode() + data + b"\nendstream"


def hierarchical_form_objects() -> list[bytes]:
    content = b"BT /F1 12 Tf 72 760 Td (Name) Tj 0 -40 Td (Email) Tj ET"
    return [
        b"<< /Type /Catalog /Pages 2 0 R /AcroForm 5 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R "
        b"/Resources << /Font << /F1 9 0 R >> >> /Annots [7 0 R 8 0 R] >>",
        stream(content),
        b"<< /Fields [6 0 R] /DA (/F1 12 Tf 0 g) /DR << /Font << /F1 9 0 R >> >> >>",
        b"<< /T (person) /FT /Tx /DA (/F1 12 Tf 0 g) /Kids [7 0 R 8 0 R] >>",
        b"<< /Type /Annot /Subtype /Widget /Parent 6 0 R /T (name) /Rect [180 752 430 774] /P 3 0 R /F 4 >>",
        b"<< /Type /Annot /Subtype /Widget /Parent 6 0 R /T (email) /Rect [180 712 430 734] /P 3 0 R /F 4 >>",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>",
    ]


def xfa_only_objects() -> list[bytes]:
    xdp = (
        b'<?xml version="1.0" encoding="UTF-8"?>\n'
        b'<xdp:xdp xmlns:xdp="http://ns.adobe.com/xdp/"><template xmlns="http://www.xfa.org/schema/xfa-template/3.3/">'
        b'<subform name="form1"><field name="full_name"/></subform></template></xdp:xdp>'
    )
    content = b"BT /F1 12 Tf 72 760 Td (Please wait... this form needs an XFA-capable viewer.) Tj ET"
    return [
        b"<< /Type /Catalog /Pages 2 0 R /AcroForm 5 0 R /NeedsRendering true >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R "
        b"/Resources << /Font << /F1 7 0 R >> >> >>",
        stream(content),
        b"<< /Fields [] /XFA 6 0 R >>",
        stream(xdp),
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    ]


# --------------------------------------------------------------------------
# Compression, security, versions
# --------------------------------------------------------------------------


def build_structure_variants() -> None:
    src = OUT / "text_multi_page.pdf"

    qpdf("--object-streams=generate", "--compress-streams=y", str(src), str(OUT / "text_object_streams.pdf"))
    record(
        "text_object_streams.pdf",
        "text_multi_page.pdf with compressed object streams and a cross-reference stream.",
        classic(usesObjectStreams=True, usesCrossReferenceStreams=True, hasClassicTrailer=False, isReadable=False, isIncrementallyWritable=False),
        "qpdf --object-streams=generate",
    )

    qpdf("--linearize", str(src), str(OUT / "text_linearized.pdf"))
    record(
        "text_linearized.pdf",
        "text_multi_page.pdf linearized for fast web view (two xref sections).",
        classic(revisionCount=2),
        "qpdf --linearize",
    )

    qpdf("--force-version=2.0", str(OUT / "text_single_page.pdf"), str(OUT / "pdf_version_2_0.pdf"))
    record("pdf_version_2_0.pdf", "text_single_page.pdf with a PDF 2.0 header.", classic(version="2.0"), "qpdf --force-version=2.0")

    encrypted = classic(isEncrypted=True, isReadable=False, isIncrementallyWritable=False)
    qpdf("--encrypt", "user123", "owner123", "256", "--", str(src), str(OUT / "encrypted_aes256_user_password.pdf"))
    record(
        "encrypted_aes256_user_password.pdf",
        "AES-256 encryption; user password 'user123', owner password 'owner123'.",
        {**encrypted, "usesObjectStreams": None, "usesCrossReferenceStreams": None, "hasClassicTrailer": None},
        "qpdf --encrypt 256",
    )

    qpdf("--encrypt", "", "owner123", "128", "--use-aes=y", "--print=none", "--modify=none", "--", str(src), str(OUT / "encrypted_aes128_owner_only.pdf"))
    record(
        "encrypted_aes128_owner_only.pdf",
        "AES-128 encryption with an empty user password (opens without a prompt) and printing/modifying restricted.",
        {**encrypted, "usesObjectStreams": None, "usesCrossReferenceStreams": None, "hasClassicTrailer": None},
        "qpdf --encrypt 128 --use-aes=y",
    )

    qpdf("--allow-weak-crypto", "--encrypt", "user", "owner", "40", "--", str(OUT / "text_single_page.pdf"), str(OUT / "encrypted_rc4_40.pdf"))
    record(
        "encrypted_rc4_40.pdf",
        "Legacy RC4 40-bit encryption; user password 'user', owner password 'owner'.",
        {**encrypted, "usesObjectStreams": None, "usesCrossReferenceStreams": None, "hasClassicTrailer": None},
        "qpdf --encrypt 40",
    )

    qpdf("--encrypt", "", "owner123", "256", "--", str(OUT / "form_classic.pdf"), str(OUT / "form_encrypted.pdf"))
    record(
        "form_encrypted.pdf",
        "form_classic.pdf with AES-256 encryption and an empty user password.",
        {**encrypted, "hasAcroForm": True, "usesObjectStreams": None, "usesCrossReferenceStreams": None, "hasClassicTrailer": None},
        "qpdf --encrypt 256",
    )


# --------------------------------------------------------------------------
# Broken and borderline files
# --------------------------------------------------------------------------


def build_broken() -> None:
    (OUT / "not_a_pdf.pdf").write_bytes(b"This is a plain text file with a .pdf extension.\n")
    record(
        "not_a_pdf.pdf",
        "Plain text with a .pdf extension.",
        {"isPdf": False, "isReadable": False, "isIncrementallyWritable": False},
        "hand-written",
    )

    good = (OUT / "text_multi_page.pdf").read_bytes()
    (OUT / "truncated.pdf").write_bytes(good[: len(good) // 2])
    record(
        "truncated.pdf",
        "First half of text_multi_page.pdf: no xref, no trailer, no %%EOF.",
        {"isPdf": True, "hasClassicTrailer": False, "isReadable": True, "isIncrementallyWritable": False, "revisionCount": 0},
        "hand-written (truncation)",
    )

    single = (OUT / "text_single_page.pdf").read_bytes()
    (OUT / "junk_before_header.pdf").write_bytes(b"JUNK" * 64 + b"\n" + single)
    record(
        "junk_before_header.pdf",
        "text_single_page.pdf with 257 bytes of junk before %PDF- (allowed: readers accept up to 1024).",
        classic(),
        "hand-written",
    )

    start = single.rindex(b"\nxref") + 1
    table_end = single.index(b"trailer", start)
    table = single[start:table_end]
    lines = table.split(b"\n")
    broken_lines = [lines[0], lines[1]] + [
        (b"0000000000" + line[10:]) if line.endswith(b" n ") else line for line in lines[2:]
    ]
    broken = single[:start] + b"\n".join(broken_lines) + single[table_end:]
    (OUT / "broken_xref_offsets.pdf").write_bytes(broken)
    record(
        "broken_xref_offsets.pdf",
        "text_single_page.pdf with every xref offset set to 0; viewers must rebuild the xref.",
        classic(),
        "hand-written",
    )

    compressed_page = zlib.compress(b"BT /F1 24 Tf 72 700 Td (Flate content stream) Tj ET")
    write_raw_pdf(
        OUT / "flate_content_stream.pdf",
        [
            b"<< /Type /Catalog /Pages 2 0 R >>",
            b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>",
            stream(compressed_page, "/Filter /FlateDecode "),
            b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        ],
    )
    record(
        "flate_content_stream.pdf",
        "Classic structure whose page content stream is Flate-compressed (binary bytes inside a stream).",
        classic(),
        "hand-written",
    )


PASSWORDS = {
    "encrypted_aes256_user_password.pdf": "user123",
    "encrypted_rc4_40.pdf": "user",
}


def add_page_counts(fixtures: list[dict]) -> None:
    """Records qpdf's page count per fixture (null when qpdf cannot read it)."""
    for entry in fixtures:
        password = PASSWORDS.get(entry["file"], "")
        result = subprocess.run(
            ["qpdf", f"--password={password}", "--show-npages", str(OUT / entry["file"])],
            capture_output=True,
            text=True,
        )
        # qpdf exits 3 for "succeeded with warnings" (for example repaired files).
        ok = result.returncode in (0, 3) and result.stdout.strip().isdigit()
        entry["pageCount"] = int(result.stdout.strip()) if ok else None


def main() -> None:
    import sys

    if "--page-counts-only" in sys.argv:
        manifest = json.loads((OUT / "manifest.json").read_text())
        add_page_counts(manifest["fixtures"])
        (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        print("Updated page counts in manifest.json")
        return
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    build_plain()
    build_forms()
    build_structure_variants()
    build_broken()
    add_page_counts(MANIFEST)
    manifest = {
        "note": "Generated by tool/generate_fixtures.py. A null expectation means 'not checked' "
        "(for example, structure markers inside encrypted files). pageCount is what qpdf "
        "reports, or null when qpdf cannot read the file.",
        "fixtures": MANIFEST,
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Wrote {len(MANIFEST)} fixtures to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
