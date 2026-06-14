# CV

A static personal résumé site: one structured content file is rendered into a typeset PDF and a TeX-styled HTML page, then published to S3/CloudFront under `guyhf.com`.

## Language

**Source of truth**:
`resume.yaml` — the single structured file holding all résumé content. Both outputs derive from it.
_Avoid_: master copy, `resume.tex` (now a generated artifact, not the source)

**Build**:
`build.py` rendering `resume.yaml` through the Jinja2 templates into the `output/` directory.
_Avoid_: compile (reserve "compile" for the `pdflatex` step specifically)

**Distribution**:
A CloudFront distribution fronting one S3 origin bucket; there is one per served subdomain (`www`, `resume`).
_Avoid_: CDN, endpoint

**Origin**:
The private S3 bucket a distribution reads from via Origin Access Control. Never served to visitors directly.
_Avoid_: website endpoint (the old public S3 website URL, being retired)
