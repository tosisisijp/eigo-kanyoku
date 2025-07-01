function Invoke-AnkiCardCheck {
    # 1. マスターデータの読み込みと解析
    Write-Host "Reading master data from tango/back.md..."
    $masterFileContent = Get-Content -Path "tango/back.md" -Raw
    $masterData = @{}
    $regex = '\|\s*\*\*([^\*]+)\*\*\s*\|\s*[^\|]+\|\s*([^\|]+)\s*\|'
    ([regex]::Matches($masterFileContent, $regex)) | ForEach-Object {
        $expression = $_.Groups[1].Value.Trim().ToLower().Replace(' ', '-')
        $label = $_.Groups[2].Value.Trim()
        if (-not [string]::IsNullOrEmpty($expression)) {
            $masterData[$expression] = $label
        }
    }
    Write-Host "Master data loaded for $($masterData.Count) expressions."
    # 2. 対象ファイルの取得 (hinshiフォルダと一部のREADMEを除外)
    $targetFiles = Get-ChildItem -Path "." -Filter "*.md" -Recurse | Where-Object { 
        $_.FullName -notlike "*tango/hinshi*" -and 
        $_.FullName -notlike "*README.md"
    }
    Write-Host "Found $($targetFiles.Count) files to check."
    # 3. 結果格納用ハッシュテーブル
    $results = @{
        "MismatchedAnkiLabel" = [System.Collections.ArrayList]::new()
        "IncorrectListMarker" = [System.Collections.ArrayList]::new()
    }
    # 4. 各ファイルのチェック
    foreach ($file in $targetFiles) {
        # tango/back.md 自体はスキップ
        if ($file.FullName.Contains("tango\back.md")) { continue }
        $fileContent = Get-Content -Path $file.FullName -Raw
        $fileNameParts = $file.BaseName.Split('-')
        if ($fileNameParts.Length -lt 2) { continue } # 日本語訳がないファイル名はスキップ
        $fileNameBase = $fileNameParts[0..($fileNameParts.Length - 2)] -join '-'
        # Ankiラベルチェック
        if ($masterData.ContainsKey($fileNameBase)) {
            $expectedLabel = $masterData[$fileNameBase]
            $actualLabelMatch = [regex]::Match($fileContent, 'AnkiLabel:\s*(.+)')
            if ($actualLabelMatch.Success) {
                $actualLabel = $actualLabelMatch.Groups[1].Value.Trim()
                if ($actualLabel -ne $expectedLabel) {
                    [void]$results["MismatchedAnkiLabel"].Add("File: $($file.Name), Expected: '$expectedLabel', Actual: '$actualLabel'")
                }
            }
        }
        # リストマーカーチェック
        $relatedSectionMatch = [regex]::Match($fileContent, '(?s)# 関連表現\s*\n(.*?)(?=\n#|$)')
        if ($relatedSectionMatch.Success) {
            $relatedSection = $relatedSectionMatch.Groups[1].Value
            if ($relatedSection -match "(?m)^\s*-\s*\[\[" ) { 
                 [void]$results["IncorrectListMarker"].Add("File: $($file.Name)")
            }
        }
    }
    # 5. 結果の表示
    Write-Host "`n=== Anki Card Validation Results ===" -ForegroundColor Yellow
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
    if (($results.MismatchedAnkiLabel.Count -eq 0) -and ($results.IncorrectListMarker.Count -eq 0)) {
        Write-Host "`nAll checks passed successfully!"
    }
}
