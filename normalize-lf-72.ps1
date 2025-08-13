$ErrorActionPreference = 'Stop'

$files = @(
    'look-up-調べる.md',
    'look-up-人を探す.md',
    'look-up-状況が上向く.md',
    'look-up-to-尊敬する.md'
)

foreach ($file in $files) {
    $path = Resolve-Path -LiteralPath $file
    $text = [System.IO.File]::ReadAllText($path)
    # Normalize to LF only
    $text = $text -replace "`r`n", "`n"
    $text = $text -replace "`r", ""
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

foreach ($file in $files) {
    $path = Resolve-Path -LiteralPath $file
    $content = [System.IO.File]::ReadAllText($path)
    if ($content.Contains("`r")) {
        Write-Host "CR found: $file"
    } else {
        Write-Host "OK (LF): $file"
    }
}


