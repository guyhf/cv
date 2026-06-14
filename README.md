# cv

Source for [www.guyhf.com](https://www.guyhf.com/) — a résumé published as a
typeset PDF and a TeX-styled HTML page.

## How it works

`resume.yaml` is the single source of truth. `build.py` renders it through two
Jinja2 templates:

```
resume.yaml ──┬─ templates/resume.tex.j2  ──▶ output/resume.tex ──pdflatex──▶ PDF
              └─ templates/resume.html.j2 ──▶ output/index.html (self-contained)
```

- The **HTML** is a single self-contained file: vendored [latex.css](https://latex.css.dev/)
  plus the Latin Modern fonts embedded as base64 data URIs, so it renders as a
  Computer Modern / TeX document with no external requests.
- The **PDF** is real LaTeX, compiled from the generated `output/resume.tex`
  against the classic `res.sty` résumé class.

Rich-text fields in `resume.yaml` support a tiny inline markup, escaped per
output format: `**bold**`, `_italic_`, `__underline__`, `[text](url)`.

## Build locally

```sh
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python build.py                                   # -> output/index.html, output/resume.tex
pdflatex -output-directory=output output/resume.tex         # -> output/resume.pdf
```

`res.sty` lives in the repo root, so run `pdflatex` from there. Open
`output/index.html` in a browser to preview the web version.

## Deploy

Pushing to `master` triggers `.github/workflows/ci.yml`, which builds the site
and deploys `output/` to the `www.guyhf.com` and `resume.guyhf.com` S3 buckets.

## Infrastructure

HTTPS is served via CloudFront + ACM in front of private S3 buckets (Origin
Access Control). The infrastructure is defined as Terraform under `infra/`.
See [`docs/adr/`](docs/adr/) for the architectural decisions.
