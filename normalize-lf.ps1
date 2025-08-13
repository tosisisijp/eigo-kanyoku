$ErrorActionPreference = 'Stop'

$files = @(
    # No.70
    'go-through-経験する.md',
    'go-through-検討する.md',
    'go-through-承認を経る.md',
    'go-through-調査する.md',
    'go-through-決済が通る.md',
    'go-through-物理的に通る.md',
    'go-through-with-やり遂げる.md',
    # No.71
    'put-up-設置する.md',
    'put-up-宿泊させる.md',
    'put-up-推薦する.md',
    'put-up-抵抗する.md',
    'put-up-値上げする.md',
    'put-up-with-我慢する.md'
)

foreach ($file in $files) {
    $path = Resolve-Path -LiteralPath $file
    $text = [System.IO.File]::ReadAllText($path)
    # Normalize to LF only
    $text = $text -replace "`r`n", "`n"
    $text = $text -replace "`r", ""
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

# Verification: report any files that still contain CR characters
$hasIssue = $false
foreach ($file in $files) {
    $content = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $file))
    if ($content.Contains("`r")) {
        Write-Host "CR found in: $file"
        $hasIssue = $true
    } else {
        Write-Host "OK (LF): $file"
    }
}

if ($hasIssue) { exit 1 } else { Write-Host 'LF normalization complete.' }


