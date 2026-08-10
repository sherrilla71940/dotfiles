$ErrorActionPreference = "Stop"

$inputJson = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($inputJson)) {
    exit 0
}

try {
    $data = $inputJson | ConvertFrom-Json
} catch {
    Write-Error "Claude status line received invalid JSON: $($_.Exception.Message)"
    exit 1
}

$parts = @()
$model = [string]$data.model.display_name
$currentDirectory = [string]$data.workspace.current_dir
$usedPercentage = $data.context_window.used_percentage

if (-not [string]::IsNullOrWhiteSpace($model)) {
    $parts += "[$model]"
}

if (-not [string]::IsNullOrWhiteSpace($currentDirectory)) {
    $directoryName = Split-Path -Leaf $currentDirectory.TrimEnd("\", "/")
    if (-not [string]::IsNullOrWhiteSpace($directoryName)) {
        $parts += $directoryName
    }
}

if ($null -ne $usedPercentage) {
    $parts += "{0}% context" -f [math]::Round([double]$usedPercentage)
}

Write-Output ($parts -join " | ")
