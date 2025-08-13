$ErrorActionPreference = 'Stop'

$files = @(
    'come-down-from-高所から降りる.md',
    'come-down-数値が下がる.md',
    'come-down-from-～から降りる.md',
    'come-down-天候が悪化する.md',
    'come-down-決定が下る.md',
    'come-down-through-通って下りる.md'
)

foreach ($file in $files) {
    $path = Resolve-Path -LiteralPath $file
    $text = [System.IO.File]::ReadAllText($path)
    # Normalize to CRLF
    $text = $text -replace "`r?`n", "`r`n"
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

Write-Host 'CRLF normalization complete.'


