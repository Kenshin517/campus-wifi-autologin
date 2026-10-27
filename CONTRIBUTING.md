# Contributing

Thanks for helping improve campus-wifi-autologin!

## Reporting a problem

Open an [issue](https://github.com/Kenshin517/campus-wifi-autologin/issues/new/choose)
and include your OS and the relevant log lines (see the README). Never paste your password.

## Making changes

1. Fork the repository and create a branch: `git checkout -b fix/short-description`.
2. Keep the Windows and Linux implementations behaviourally in sync where it makes sense.
3. Check your changes locally:
   - Linux: `shellcheck -x linux/bin/campus-wifi-autologin linux/*.sh` and `linux/build-deb.sh`
   - Windows: keep `.ps1` files **ASCII-only** (Windows PowerShell 5.1 reads BOM-less
     files as ANSI) and run `Invoke-ScriptAnalyzer -Path windows -Recurse`.
4. Add an entry under a new version in `CHANGELOG.md` and bump `VERSION` in
   `linux/bin/campus-wifi-autologin` if the change is user-visible.
5. Open a pull request describing what changed and how you tested it.

## Style

- Bash: `set -uo pipefail`, quote every expansion, no `eval`, no sourcing of user data.
- PowerShell: approved verbs, `[CmdletBinding()]`, no aliases in scripts.
- Never log or print credentials.
