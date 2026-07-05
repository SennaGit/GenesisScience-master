# scripts

Repo tooling.

- `release/` — packaging and release scripts (Tauri build matrix, signing/notarization
  helpers, GitHub Release upload, `latest.json` generation).
- `dev/` — local development helpers:
  - `fetch-opencode.sh` / `fetch-opencode.ps1` fetch the pinned OpenCode sidecar.
  - `fetch-uv.sh` / `fetch-uv.ps1` fetch the pinned `uv` sidecar.
  - `fetch-skills.sh` / `fetch-skills.ps1` fetch the bundled third-party skills pack.
  - `bootstrap.mjs` is the cross-platform `pnpm bootstrap:runtime` entry.
  - `windows-first-run-smoke.ps1` is the repeatable Windows first-run smoke check.
