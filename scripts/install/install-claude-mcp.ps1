$ErrorActionPreference = "Stop"

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    throw "Claude Code is not installed or is not available on PATH."
}

$manifestPath = Join-Path $PSScriptRoot "..\manifests\claude-user-mcp-servers.json"
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json

foreach ($server in $manifest.mcpServers.PSObject.Properties) {
    & claude mcp get $server.Name *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "$($server.Name) is already configured; leaving the live definition unchanged."
        continue
    }

    $configuration = $server.Value | ConvertTo-Json -Depth 10 -Compress
    & claude mcp add-json --scope user $server.Name $configuration
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to add Claude MCP server '$($server.Name)'."
    }
}
