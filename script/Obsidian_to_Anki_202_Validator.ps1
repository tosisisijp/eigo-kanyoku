function Test-Obsidian_to_Anki_202Format {
    param([string]$FilePath)
    
    if (!(Test-Path $FilePath)) { 
        Write-Host "❌ ファイルが見つかりません: $FilePath" -ForegroundColor Red
        return $false
    }
    
    $content = Get-Content $FilePath -Raw -Encoding UTF8
    Write-Host "`n=== $FilePath 202形式検証 ===" -ForegroundColor Cyan
    
    # 1. Obsidian_to_Ankiセクション存在確認
    $sectionMatches = [regex]::Matches($content, "# Obsidian_to_Anki")
    if ($sectionMatches.Count -eq 0) {
        Write-Host "❌ Obsidian_to_Ankiセクション不存在" -ForegroundColor Red
        return $false
    } elseif ($sectionMatches.Count -gt 1) {
        Write-Host "❌ Obsidian_to_Ankiセクション重複 ($($sectionMatches.Count)個)" -ForegroundColor Red
        return $false
    } else {
        Write-Host "✅ Obsidian_to_Ankiセクション存在（1個）" -ForegroundColor Green
    }
    
    # 2. START/ENDマーカー確認
    $startExists = $content -match "START"
    $endExists = $content -match "END"
    
    if (-not $startExists) {
        Write-Host "❌ STARTマーカー不存在" -ForegroundColor Red
        return $false
    }
    if (-not $endExists) {
        Write-Host "❌ ENDマーカー不存在" -ForegroundColor Red
        return $false
    }
    
    Write-Host "✅ START/ENDマーカー存在" -ForegroundColor Green
    
    # 3. ENDマーカー詳細検証（バイナリレベル）
    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    $endIndex = -1
    
    # ENDマーカー位置を特定
    for ($i = 0; $i -lt $bytes.Length - 2; $i++) {
        if ($bytes[$i] -eq 69 -and $bytes[$i+1] -eq 78 -and $bytes[$i+2] -eq 68) { 
            $endIndex = $i + 3
            break 
        }
    }
    
    if ($endIndex -eq -1) {
        Write-Host "❌ ENDマーカーがバイナリレベルで見つかりません" -ForegroundColor Red
        return $false
    }
    
    # ENDの後のバイト確認
    if ($endIndex -ge $bytes.Length) {
        Write-Host "❌ ENDでファイル末尾（改行コードなし）" -ForegroundColor Red
        return $false
    }
    
    $afterEndBytes = $bytes[$endIndex..($bytes.Length-1)]
    Write-Host "ENDの後のバイト: " -NoNewline
    $afterEndBytes[0..([Math]::Min(4, $afterEndBytes.Length-1))] | ForEach-Object { 
        Write-Host ("{0:X2} " -f $_) -NoNewline 
    }
    Write-Host ""
    
    # ENDスペース問題チェック
    if ($afterEndBytes.Length -ge 1 -and $afterEndBytes[0] -eq 0x20) {
        Write-Host "❌ ENDの直後にスペース (20)" -ForegroundColor Red
        return $false
    }
    
    # 改行コード確認
    if ($afterEndBytes.Length -ge 1 -and $afterEndBytes[0] -eq 0x0A) {
        Write-Host "✅ ENDの後にLF改行コード" -ForegroundColor Green
    } else {
        Write-Host "❌ ENDの後の改行コード不正" -ForegroundColor Red
        return $false
    }
    
    # 4. WithSpeech確認
    if ($content -match "WithSpeech") {
        Write-Host "✅ WithSpeech存在" -ForegroundColor Green
    } else {
        Write-Host "⚠️ WithSpeech不存在" -ForegroundColor Yellow
    }
    
    # 5. Back:セクション確認
    if ($content -match "Back:") {
        Write-Host "✅ Back:セクション存在" -ForegroundColor Green
    } else {
        Write-Host "❌ Back:セクション不存在" -ForegroundColor Red
        return $false
    }
    
    # 6. Speech行確認
    if ($content -match "Speech:") {
        Write-Host "✅ Speech行存在" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Speech行不存在" -ForegroundColor Yellow
    }
    
    # 7. Tags行確認
    if ($content -match "Tags:") {
        Write-Host "✅ Tags行存在" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Tags行不存在" -ForegroundColor Yellow
    }
    
    Write-Host "✅ 202形式検証完了" -ForegroundColor Green
    return $true
}

function Test-All-Obsidian_to_Anki_202Format {
    $mdFiles = Get-ChildItem -Path "." -Filter "*.md" | Where-Object { $_.Name -notlike "README.md" }
    Write-Host "=== 全mdファイル 202形式検証開始 ===" -ForegroundColor Magenta
    Write-Host "対象ファイル数: $($mdFiles.Count)" -ForegroundColor Magenta
    
    $results = @{
        "正常" = @()
        "セクション不存在" = @()
        "セクション重複" = @()
        "マーカー不存在" = @()
        "ENDスペース問題" = @()
        "改行コード問題" = @()
        "その他問題" = @()
    }
    
    foreach ($file in $mdFiles) {
        $content = Get-Content $file.FullName -Raw -Encoding UTF8
        $sectionCount = ([regex]::Matches($content, "# Obsidian_to_Anki")).Count
        
        if ($sectionCount -eq 0) {
            $results["セクション不存在"] += $file.Name
        } elseif ($sectionCount -gt 1) {
            $results["セクション重複"] += $file.Name
        } else {
            # 詳細検証
            $hasStart = $content -match "START"
            $hasEnd = $content -match "END"
            
            if (-not $hasStart -or -not $hasEnd) {
                $results["マーカー不存在"] += $file.Name
            } else {
                # ENDマーカー詳細確認
                $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
                $endIndex = -1
                
                for ($i = 0; $i -lt $bytes.Length - 2; $i++) {
                    if ($bytes[$i] -eq 69 -and $bytes[$i+1] -eq 78 -and $bytes[$i+2] -eq 68) { 
                        $endIndex = $i + 3
                        break 
                    }
                }
                
                if ($endIndex -ne -1 -and $endIndex -lt $bytes.Length) {
                    $afterEndBytes = $bytes[$endIndex..($bytes.Length-1)]
                    
                    if ($afterEndBytes.Length -ge 1 -and $afterEndBytes[0] -eq 0x20) {
                        $results["ENDスペース問題"] += $file.Name
                    } elseif ($afterEndBytes.Length -ge 1 -and $afterEndBytes[0] -eq 0x0A) {
                        $results["正常"] += $file.Name
                    } else {
                        $results["改行コード問題"] += $file.Name
                    }
                } else {
                    $results["改行コード問題"] += $file.Name
                }
            }
        }
    }
    
    # 結果表示
    Write-Host "`n=== 202形式検証結果サマリー ===" -ForegroundColor Magenta
    foreach ($category in $results.Keys) {
        $count = $results[$category].Count
        if ($count -gt 0) {
            $color = switch ($category) {
                "正常" { "Green" }
                "セクション不存在" { "Yellow" }
                default { "Red" }
            }
            Write-Host "$category ($count 件):" -ForegroundColor $color
            $results[$category] | ForEach-Object { Write-Host "  - $_" -ForegroundColor $color }
            Write-Host ""
        }
    }
    
    return $results
}

Write-Host "✅ Obsidian_to_Anki 202形式検証関数を読み込みました" -ForegroundColor Green
Write-Host "使用方法:" -ForegroundColor Cyan
Write-Host "  Test-All-Obsidian_to_Anki_202Format  # 全ファイル一括検証" -ForegroundColor Cyan
Write-Host "  Test-Obsidian_to_Anki_202Format -FilePath 'ファイル名.md'  # 個別検証" -ForegroundColor Cyan 