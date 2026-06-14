#!/usr/bin/env python3
"""Render resume.yaml into LaTeX (-> PDF) and self-contained HTML.

This replaces the old ltoh.pl Perl converter. resume.yaml is the single source
of truth; two Jinja2 templates turn it into resume.tex (compiled by pdflatex)
and index.html (styled with vendored latex.css + bundled Latin Modern fonts).

Rich-text fields support a tiny inline markup, escaped per target:
    **bold**   _italic_   __underline__   [text](url)
"""

from __future__ import annotations

import html
import re
from pathlib import Path

import yaml
from jinja2 import Environment, FileSystemLoader, StrictUndefined
from markupsafe import Markup

ROOT = Path(__file__).resolve().parent
TEMPLATES = ROOT / "templates"
ASSETS = ROOT / "assets"
OUTPUT = ROOT / "output"

# --------------------------------------------------------------------------- #
# Inline rich-text rendering
# --------------------------------------------------------------------------- #

# One alternation, scanned left-to-right. Order matters: the link and the
# double-underscore underline must be tried before the single-underscore italic.
_INLINE_RE = re.compile(
    r"\[(?P<ltext>[^\]]+)\]\((?P<url>[^)]+)\)"  # [text](url)
    r"|\*\*(?P<bold>.+?)\*\*"                    # **bold**
    r"|__(?P<ul>.+?)__"                          # __underline__
    r"|_(?P<it>.+?)_"                            # _italic_
)

_LATEX_MAP = {
    # Special characters that must be escaped.
    "\\": r"\textbackslash{}",
    "&": r"\&",
    "%": r"\%",
    "$": r"\$",
    "#": r"\#",
    "_": r"\_",
    "{": r"\{",
    "}": r"\}",
    "~": r"\textasciitilde{}",
    "^": r"\textasciicircum{}",
    # Unicode punctuation and accents -> classic LaTeX, so the PDF preamble can
    # stay OT1 with no inputenc/fontenc (preserving the original font metrics).
    "–": "--",
    "—": "---",
    "’": "'",
    "‘": "`",
    "“": "``",
    "”": "''",
    "á": r"\'a", "é": r"\'e", "í": r"\'i", "ó": r"\'o", "ú": r"\'u", "ñ": r"\~n", "ü": r'\"u',
    "Á": r"\'A", "É": r"\'E", "Í": r"\'I", "Ó": r"\'O", "Ú": r"\'U", "Ñ": r"\~N", "Ü": r'\"U',
}


def _latex_escape(text: str) -> str:
    """Escape LaTeX specials and fold Unicode punctuation/accents to commands."""
    escaped = "".join(_LATEX_MAP.get(ch, ch) for ch in text)
    # Render the standalone words LaTeX/TeX as their logos in the PDF. Applied to
    # escaped literal text only (never to raw \href URLs); LaTeX before TeX so the
    # "TeX" inside "LaTeX" isn't matched separately.
    escaped = re.sub(r"\bLaTeX\b", r"\\LaTeX{}", escaped)
    escaped = re.sub(r"\bTeX\b", r"\\TeX{}", escaped)
    return escaped


def _html_escape(text: str) -> str:
    return html.escape(text, quote=False)


def _render(text: str, target: str) -> str:
    """Render inline markup for 'latex' or 'html', escaping literal text."""
    esc = _latex_escape if target == "latex" else _html_escape
    out: list[str] = []
    pos = 0
    for m in _INLINE_RE.finditer(text):
        out.append(esc(text[pos : m.start()]))
        if m.group("ltext") is not None:
            label, url = m.group("ltext"), m.group("url")
            if target == "latex":
                # hyperref's \href handles raw URL characters; do not escape the
                # URL, only the visible label.
                out.append(r"\href{%s}{%s}" % (url, esc(label)))
            else:
                out.append(
                    '<a href="%s">%s</a>'
                    % (html.escape(url, quote=True), _html_escape(label))
                )
        elif m.group("bold") is not None:
            inner = esc(m.group("bold"))
            out.append(
                r"\textbf{%s}" % inner if target == "latex" else "<strong>%s</strong>" % inner
            )
        elif m.group("ul") is not None:
            inner = esc(m.group("ul"))
            out.append(
                r"\underline{%s}" % inner if target == "latex" else "<u>%s</u>" % inner
            )
        elif m.group("it") is not None:
            inner = esc(m.group("it"))
            out.append(
                r"\textit{%s}" % inner if target == "latex" else "<em>%s</em>" % inner
            )
        pos = m.end()
    out.append(esc(text[pos:]))
    return "".join(out)


def tex_filter(text) -> str:
    return _render("" if text is None else str(text), "latex")


def html_filter(text) -> Markup:
    return Markup(_render("" if text is None else str(text), "html"))


# --------------------------------------------------------------------------- #
# Rendering
# --------------------------------------------------------------------------- #


def _read_asset(name: str) -> str:
    return (ASSETS / name).read_text(encoding="utf-8")


def _font_data_uri(name: str) -> str:
    """Base64 data: URI so the HTML stays a single self-contained file."""
    import base64

    raw = (ASSETS / name).read_bytes()
    b64 = base64.b64encode(raw).decode("ascii")
    return f"data:font/woff2;base64,{b64}"


# (file, font-weight, font-style) for the four Latin Modern faces.
_FONT_FACES = [
    ("LM-regular.woff2", "normal", "normal"),
    ("LM-italic.woff2", "normal", "italic"),
    ("LM-bold.woff2", "bold", "normal"),
    ("LM-bold-italic.woff2", "bold", "italic"),
]


def _font_face_css() -> str:
    blocks = []
    for fname, weight, style in _FONT_FACES:
        blocks.append(
            "@font-face{font-family:'Latin Modern';font-weight:%s;font-style:%s;"
            "font-display:swap;src:url('%s') format('woff2');}"
            % (weight, style, _font_data_uri(fname))
        )
    return "\n".join(blocks)


def latex_env() -> Environment:
    env = Environment(
        loader=FileSystemLoader(str(TEMPLATES)),
        block_start_string="((*",
        block_end_string="*))",
        variable_start_string="(((",
        variable_end_string=")))",
        comment_start_string="((#",
        comment_end_string="#))",
        trim_blocks=True,
        lstrip_blocks=True,
        autoescape=False,
        undefined=StrictUndefined,
    )
    env.filters["tex"] = tex_filter
    return env


def html_env() -> Environment:
    env = Environment(
        loader=FileSystemLoader(str(TEMPLATES)),
        trim_blocks=True,
        lstrip_blocks=True,
        autoescape=True,
        undefined=StrictUndefined,
    )
    env.filters["rich"] = html_filter
    return env


def main() -> None:
    data = yaml.safe_load((ROOT / "resume.yaml").read_text(encoding="utf-8"))
    OUTPUT.mkdir(exist_ok=True)

    tex = latex_env().get_template("resume.tex.j2").render(**data)
    (OUTPUT / "resume.tex").write_text(tex, encoding="utf-8")

    page = html_env().get_template("resume.html.j2").render(
        css=_read_asset("latex.css"),
        font_face_css=_font_face_css(),
        **data,
    )
    (OUTPUT / "index.html").write_text(page, encoding="utf-8")

    print("Wrote output/resume.tex and output/index.html")


if __name__ == "__main__":
    main()
