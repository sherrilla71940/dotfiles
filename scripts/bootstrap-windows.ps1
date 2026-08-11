# Run once on a new Windows machine, by hand. Deliberately NOT a chezmoi script: anything
# under home/.chezmoiscripts/ runs on every `chezmoi apply`, which meant a routine apply
# could install software unexpectedly.
$ErrorActionPreference = "Stop"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget is required. Install 'App Installer' from the Microsoft Store, then rerun."
}

foreach ($id in @("Git.Git", "jqlang.jq", "twpayne.chezmoi")) {
    # winget list exits non-zero when nothing matches, so check the output instead.
    $installed = winget list --id $id --exact 2>$null | Select-String -SimpleMatch $id
    if (-not $installed) {
        winget install --id $id --exact --source winget `
            --accept-package-agreements --accept-source-agreements --disable-interactivity
    } else {
        Write-Host "$id already installed"
    }
}

Write-Host 'Done. Restart your shell, run "chezmoi diff", review the changes, then run "chezmoi apply -v".'
