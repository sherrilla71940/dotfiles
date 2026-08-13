# Run once on a new Windows machine, by hand. Deliberately NOT a chezmoi script: anything
# under home/.chezmoiscripts/ runs on every `chezmoi apply`, which meant a routine apply
# could install software unexpectedly.
$ErrorActionPreference = "Stop"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget is required. Install 'App Installer' from the Microsoft Store, then rerun."
}

$packageId = "jqlang.jq"
# The documented setup installs Git and chezmoi before cloning. This post-clone helper adds
# jq for the Claude MCP installer and verifies whether the VS Code CLI is already available.
$installed = winget list --id $packageId --exact 2>$null | Select-String -SimpleMatch $packageId
if (-not $installed) {
    winget install --id $packageId --exact --source winget `
        --accept-package-agreements --accept-source-agreements --disable-interactivity
} else {
    Write-Host "$packageId already installed"
}

if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    Write-Warning "VS Code CLI is not on PATH. Install VS Code, then enable its 'code' command."
}

Write-Host 'Optional tools are ready.'
