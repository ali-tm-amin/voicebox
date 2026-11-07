# Voicebox one-command installers (Ihsan Ops)

Free installers that set up the official, signed Voicebox release for people who
don't want to touch a terminal more than once.

| Platform | Command |
| --- | --- |
| macOS (Apple Silicon or Intel) | `curl -fsSL https://ihsanops.ai/voicebox.sh \| bash` |
| Windows 10/11 (PowerShell) | `irm https://ihsanops.ai/voicebox.ps1 \| iex` |

`ihsanops.ai/voicebox.sh` and `.ps1` are served by Netlify functions in the
`ali-tm-amin/ihsanops` site repo, which fetch these files from `main` of this fork
and count downloads (country + client type only).

The scripts download the official release from `jamiepine/voicebox`, so Mac users
get the Apple-notarized build with no Gatekeeper warning. Override with
`VOICEBOX_REPO=owner/repo` to install from a different repo's releases.

Voicebox is MIT-licensed open-source software by Jamie Pine and contributors.
