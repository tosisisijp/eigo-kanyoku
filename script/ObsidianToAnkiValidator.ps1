function Test-AllObsidianToAnkiFiles {
    $mdFiles = Get-ChildItem -Path "." -Filter "*.md" | Where-Object { $_.Name -notlike "README.md" }
    
    Write-Host "=== 全mdファイル検証開始 ===" -ForegroundColor Magenta
    Write-Host "対象ファイル数: $($mdFiles.Count)" -ForegroundColor Magenta
    Write-Host ""
    
    $results = @{
        "正常" = @()
        "ENDスペース問題" = @()
        "改行コード問題" = @()
        "セクション不存在" = @()
        "マーカー不存在" = @()
        "その他問題" = @()
    }
    
    foreach ($file in $mdFiles) {
        $content = Get-Content $file.FullName -Raw
        
        if ($content -match "# Obsidian_to_Anki") {
            if ($content -match "END") {
                $endIndex = $content.LastIndexOf("END")
                $afterEndStart = $endIndex + 3
                $remainingLength = $content.Length - $afterEndStart
                
                if ($remainingLength -eq 0) {
                    $results["改行コード問題"] += $file.Name
                } else {
                    $afterEnd = $content.Substring($afterEndStart, [Math]::Min(5, $remainingLength))
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes($afterEnd)
                    
                    if ($bytes.Length -ge 1 -and $bytes[0] -eq 0x20) {
                        $results["ENDスペース問題"] += $file.Name
                    } elseif ($bytes.Length -eq 1 -and $bytes[0] -eq 0x0A) {
                        $results["改行コード問題"] += $file.Name
                    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0x0D -and $bytes[1] -eq 0x0A) {
                        $results["正常"] += $file.Name
                    } else {
                        $results["その他問題"] += $file.Name
                    }
                }
            } else {
                $results["マーカー不存在"] += $file.Name
            }
        } else {
            $results["セクション不存在"] += $file.Name
        }
    }
    
    Write-Host "=== 検証結果サマリー ===" -ForegroundColor Magenta
    foreach ($category in $results.Keys) {
        $count = $results[$category].Count
        if ($count -gt 0) {
            $color = switch ($category) {
                "正常" { "Green" }
                "セクション不存在" { "Yellow" }
                default { "Red" }
            }
            Write-Host "$category ($count 件):" -ForegroundColor $color
            $results[$category] | ForEach-Object { Write-Host "  - $_" }
            Write-Host ""
        }
    }
    
    return $results
}

function Test-ObsidianToAnkiFile {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "ファイルが見つかりません: $FilePath" -ForegroundColor Red
        return
    }
    
    Write-Host "=== $FilePath 詳細検証 ===" -ForegroundColor Cyan
    
    $content = Get-Content $FilePath -Raw
    
    # 1. Obsidian_to_Ankiセクション存在確認
    if ($content -match "# Obsidian_to_Anki") {
        Write-Host "✓ Obsidian_to_Ankiセクション: 存在" -ForegroundColor Green
        
        # 2. START/ENDマーカー確認
        if ($content -match "START" -and $content -match "END") {
            Write-Host "✓ START/ENDマーカー: 存在" -ForegroundColor Green
            
            # 3. ENDマーカー詳細分析
            $endIndex = $content.LastIndexOf("END")
            Write-Host "END位置: $endIndex" -ForegroundColor Yellow
            
            $afterEndStart = $endIndex + 3
            $remainingLength = $content.Length - $afterEndStart
            Write-Host "END後の文字数: $remainingLength" -ForegroundColor Yellow
            
            if ($remainingLength -gt 0) {
                $afterEnd = $content.Substring($afterEndStart, [Math]::Min(10, $remainingLength))
                Write-Host "END後の内容: '$afterEnd'" -ForegroundColor Yellow
                
                # 文字コード詳細分析
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($afterEnd)
                Write-Host "文字コード詳細:" -ForegroundColor Magenta
                for ($i = 0; $i -lt [Math]::Min(5, $bytes.Length); $i++) {
                    $char = if ($bytes[$i] -eq 0x0D) { "CR" } elseif ($bytes[$i] -eq 0x0A) { "LF" } elseif ($bytes[$i] -eq 0x20) { "SPACE" } else { [char]$bytes[$i] }
                    Write-Host "  [$i] 0x$($bytes[$i].ToString('X2')) ($char)" -ForegroundColor White
                }
                
                # 問題判定
                if ($bytes.Length -ge 1 -and $bytes[0] -eq 0x20) {
                    Write-Host "❌ 問題: ENDの後にスペースがあります" -ForegroundColor Red
                } elseif ($bytes.Length -eq 1 -and $bytes[0] -eq 0x0A) {
                    Write-Host "❌ 問題: 改行コードがLFのみです（CRLFが必要）" -ForegroundColor Red
                } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0x0D -and $bytes[1] -eq 0x0A) {
                    Write-Host "✓ 正常: CRLF改行コードです" -ForegroundColor Green
                } else {
                    Write-Host "❓ その他の問題があります" -ForegroundColor Yellow
                }
            } else {
                Write-Host "❌ 問題: ENDがファイル末尾にあります（改行が必要）" -ForegroundColor Red
            }
        } else {
            Write-Host "❌ START/ENDマーカー: 不存在" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Obsidian_to_Ankiセクション: 不存在" -ForegroundColor Red
    }
}

# 修正関数の追加（203番ルール準拠）

function Add-CRLFAfterEND {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "ファイルが見つかりません: $FilePath" -ForegroundColor Red
        return $false
    }
    
    try {
        $content = Get-Content $FilePath -Raw
        
        if ($content -match "END$") {
            # ENDがファイル末尾の場合、CRLF追加
            $content += "`r`n"
            Set-Content $FilePath -Value $content -NoNewline -Encoding UTF8
            Write-Host "✅ CRLF追加完了: $FilePath" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ ENDがファイル末尾ではありません: $FilePath" -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "❌ CRLF追加失敗: $FilePath - $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Remove-SpaceAfterEND {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "ファイルが見つかりません: $FilePath" -ForegroundColor Red
        return $false
    }
    
    try {
        $content = Get-Content $FilePath -Raw
        
        if ($content -match "END ") {
            # ENDの後のスペースを除去
            $content = $content -replace "END ", "END"
            Set-Content $FilePath -Value $content -NoNewline -Encoding UTF8
            Write-Host "✅ ENDスペース除去完了: $FilePath" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ ENDの後にスペースは見つかりませんでした: $FilePath" -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "❌ スペース除去失敗: $FilePath - $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Repair-AllObsidianToAnkiFiles {
    param([switch]$WhatIf)
    
    Write-Host "=== Obsidian_to_Anki形式 一括修正開始 ===" -ForegroundColor Magenta
    
    # まず検証を実行
    $results = Test-AllObsidianToAnkiFiles
    
    $repairResults = @{
        "修正済み" = @()
        "修正不要" = @()
        "修正失敗" = @()
    }
    
    # ENDスペース問題の修正
    foreach ($fileName in $results["ENDスペース問題"]) {
        if ($WhatIf) {
            Write-Host "修正予定: $fileName (ENDスペース除去)" -ForegroundColor Cyan
        } else {
            if (Remove-SpaceAfterEND $fileName) {
                $repairResults["修正済み"] += "$fileName (スペース除去)"
            } else {
                $repairResults["修正失敗"] += "$fileName (スペース除去失敗)"
            }
        }
    }
    
    # 改行コード問題の修正（ENDファイル末尾問題を含む）
    foreach ($fileName in $results["改行コード問題"]) {
        if ($WhatIf) {
            Write-Host "修正予定: $fileName (CRLF追加)" -ForegroundColor Cyan
        } else {
            if (Add-CRLFAfterEND $fileName) {
                $repairResults["修正済み"] += "$fileName (CRLF追加)"
            } else {
                $repairResults["修正失敗"] += "$fileName (CRLF追加失敗)"
            }
        }
    }
    
    # 正常ファイルは修正不要
    foreach ($fileName in $results["正常"]) {
        $repairResults["修正不要"] += $fileName
    }
    
    # 修正結果表示
    Write-Host "=== 修正結果サマリー ===" -ForegroundColor Magenta
    foreach ($category in $repairResults.Keys) {
        $count = $repairResults[$category].Count
        if ($count -gt 0) {
            $color = switch ($category) {
                "修正不要" { "Green" }
                "修正済み" { "Cyan" }
                default { "Red" }
            }
            Write-Host "$category ($count 件):" -ForegroundColor $color
            $repairResults[$category] | ForEach-Object { Write-Host "  - $_" }
            Write-Host ""
        }
    }
    
    return $repairResults
}

function Fix-ENDFormat {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "ファイルが見つかりません: $FilePath" -ForegroundColor Red
        return $false
    }
    
    try {
        $content = Get-Content $FilePath -Raw
        
        # ENDの前の余分なCRLFを除去
        # パターン: Tags行 + CRLF + CRLF + END → Tags行 + CRLF + END
        $content = $content -replace "(`r`n)`r`n(END)", '$1$2'
        
        Set-Content $FilePath -Value $content -NoNewline -Encoding UTF8
        Write-Host "✅ END形式修正完了: $FilePath" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ END形式修正失敗: $FilePath - $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# 実行部分を更新
Write-Host "PowerShell検証スクリプト読み込み完了" -ForegroundColor Green
Write-Host "使用可能な関数:" -ForegroundColor Yellow
Write-Host "  - Test-AllObsidianToAnkiFiles" -ForegroundColor White
Write-Host "  - Test-ObsidianToAnkiFile <ファイル名>" -ForegroundColor White
Write-Host "  - Repair-AllObsidianToAnkiFiles [-WhatIf]" -ForegroundColor White
Write-Host "  - Add-CRLFAfterEND <ファイル名>" -ForegroundColor White
Write-Host "  - Remove-SpaceAfterEND <ファイル名>" -ForegroundColor White
Write-Host "  - Fix-ENDFormat <ファイル名>" -ForegroundColor White 