function Invoke-AnkiCardCorrection {
    # 1. Load master data from tango/back.md
    Write-Host "--- Stage 1: Loading master data ---"
    $masterFileContent = Get-Content -Path "tango/back.md" -Raw
    $masterData = @{}
    $regex = '(?s)## Ankiラベル別実用文例.*?\| No\. \|.*?\|(.*?)\n(.*?---\n)(.*)'
    $tableContentMatch = [regex]::Match($masterFileContent, $regex)
    if ($tableContentMatch.Success) {
        $tableRows = $tableContentMatch.Groups[3].Value.Split([System.Environment]::NewLine)
        foreach ($row in $tableRows) {
            if ($row -match '\|\s*\d+\s*\|\s*\*\*([^\*]+)\*\*\s*\|.*?\|\s*([^\|]+)\s*\|') {
                $expression = $Matches[1].Trim().ToLower().Replace(' ', '-')
                $label = $Matches[2].Trim()
                if (-not [string]::IsNullOrEmpty($expression)) {
                    $masterData[$expression] = $label
                }
            }
        }
    }
    if ($masterData.Count -eq 0) {
        Write-Host "Error: Failed to load master data."
        return
    }
    Write-Host "Master data loaded for $($masterData.Count) expressions."
    # 2. Get target files
    Write-Host "`n--- Stage 2: Finding target files ---"
    $targetFiles = Get-ChildItem -Path "." -Filter "*.md" -Recurse | Where-Object { 
        $_.FullName -notlike "*tango/hinshi*" -and $_.Name -ne "README.md"
    }
    Write-Host "Found $($targetFiles.Count) files to correct."
    $correctedFiles = @()
    # 3. Correct each file
    Write-Host "`n--- Stage 3: Correcting files ---"
    foreach ($file in $targetFiles) {
        $fileContent = Get-Content $file.FullName -Raw
        $originalContent = $fileContent
        # Correct Anki Label
        $fileNameAsExpression = $file.BaseName -replace '(-[^-]+)$', ''
        if ($masterData.ContainsKey($fileNameAsExpression)) {
            $expectedLabel = $masterData[$fileNameAsExpression]
            # Replace 'Ankiラベル:'
            $fileContent = [regex]::Replace($fileContent, '(?m)^(Ankiラベル:\s*).+$', "${1}$expectedLabel")
            # Replace 'AnkiLabel:'
            $fileContent = [regex]::Replace($fileContent, '(?m)^(AnkiLabel:\s*).+$', "${1}$expectedLabel")
            # Replace in 'Tags:'
            $fileContent = [regex]::Replace($fileContent, '(Tags:.*?Ankiラベル:)[^ ]+', "${1}$expectedLabel")
        }
        # Correct list markers in '関連表現' section
        if ($fileContent -match '(?ms)(# 関連表現\s*\n)(.*)') {
            $header = $Matches[1]
            $sectionContent = $Matches[2]
            $correctedSection = [regex]::Replace($sectionContent, '(?m)^\s*-\s*(\[\[)', "・$1")
            $fileContent = $fileContent.Substring(0, $fileContent.IndexOf($header)) + $header + $correctedSection
        }
        if ($originalContent -ne $fileContent) {
            Set-Content -Path $file.FullName -Value $fileContent -Encoding UTF8
            $correctedFiles += $file.Name
        }
    }
    # 4. Report results
    Write-Host "`n--- Stage 4: Reporting results ---"
    if ($correctedFiles.Count -gt 0) {
        Write-Host "Correction completed. $($correctedFiles.Count) files were modified:" -ForegroundColor Green
        $correctedFiles | ForEach-Object { Write-Host "  - $_" }
    } else {
        Write-Host "No files needed correction." -ForegroundColor Yellow
    }
}
