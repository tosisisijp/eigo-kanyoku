function Invoke-AnkiCardCheckV2 {
    # 1. マスターデータの読み込みと解析
    Write-Host "--- Stage 1: Reading master data from tango/back.md ---"
    $masterFileContent = Get-Content -Path "tango/back.md" -Raw
    $masterData = @{}
    # Regex updated to be more robust, targeting the specific markdown table for examples.
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
                    # Write-Host "Loaded: $expression -> $label" # Uncomment for deep debug
                }
            }
        }
    }
    if ($masterData.Count -gt 0) {
        Write-Host "Master data loaded successfully for $($masterData.Count) expressions."
    } else {
        Write-Host "Error: Failed to load master data. Please check regex and file content."
        return
    }
    # 2. 対象ファイルの取得
    Write-Host "`n--- Stage 2: Finding target files ---"
    $targetFiles = Get-ChildItem -Path "." -Filter "*.md" -Recurse | Where-Object { 
        $_.FullName -notlike "*tango/hinshi*" -and 
        $_.Name -ne "README.md" -and
        $_.Name -ne "back.md" # Exclude the master file itself
    }
    Write-Host "Found $($targetFiles.Count) files to check."
    # 3. 結果格納用ハッシュテーブル
    $results = @{
        "MismatchedAnkiLabel" = [System.Collections.ArrayList]::new()
        "IncorrectListMarker" = [System.Collections.ArrayList]::new()
        "CheckedFilesCount" = 0
    }
    # 4. 各ファイルのチェック
    Write-Host "`n--- Stage 3: Checking files ---"
    foreach ($file in $targetFiles) {
        $results.CheckedFilesCount++
        $fileContent = Get-Content -Path $file.FullName -Raw
        # ファイル名から表現を抽出 (例: "get-back-to-連絡する" -> "get-back-to")
        $fileNameAsExpression = $file.BaseName -replace '(-[^-]+)$', ''
        # Ankiラベルチェック
        if ($masterData.ContainsKey($fileNameAsExpression)) {
            $expectedLabel = $masterData[$fileNameAsExpression]
            $actualLabelMatch = [regex]::Match($fileContent, 'AnkiLabel:\s*(.+?)\s*\n')
            if ($actualLabelMatch.Success) {
                $actualLabel = $actualLabelMatch.Groups[1].Value.Trim()
                if ($actualLabel -ne $expectedLabel) {
                    [void]$results["MismatchedAnkiLabel"].Add("File: $($file.Name), Expected: '$expectedLabel', Actual: '$actualLabel'")
                }
            } else {
                 [void]$results["MismatchedAnkiLabel"].Add("File: $($file.Name), Expected: '$expectedLabel', Actual: 'Label Not Found'")
            }
        }
        # リストマーカーチェック
        if ($fileContent -match '(?ms)^# 関連表現\s*\n(.*?)(?=\n#|$)') {
            $relatedSection = $Matches[1]
            if ($relatedSection -match "(?m)^\s*-\s*\[\[" ) { 
                 if (-not $results["IncorrectListMarker"].Contains($file.Name)) {
                    [void]$results["IncorrectListMarker"].Add($file.Name)
                 }
            }
        }
    }
    Write-Host "Checked $($results.CheckedFilesCount) files."
    # 5. 結果の表示
    Write-Host "`n--- Stage 4: Reporting results ---"
    if ($results["MismatchedAnkiLabel"].Count -gt 0) {
        Write-Host "`n[!] Mismatched Anki Labels Found:" -ForegroundColor Red
        $results["MismatchedAnkiLabel"] | ForEach-Object { Write-Host "  - $_" }
    } else {
        Write-Host "`n[✓] All checked Anki Labels are consistent." -ForegroundColor Green
    }
    if ($results["IncorrectListMarker"].Count -gt 0) {
        Write-Host "`n[!] Incorrect List Markers Found (`-` instead of `・`):" -ForegroundColor Red
        ($results["IncorrectListMarker"] | Sort-Object -Unique) | ForEach-Object { Write-Host "  - $_" }
    } else {
        Write-Host "`n[✓] All list markers in '関連表現' sections are correct." -ForegroundColor Green
    }
}
