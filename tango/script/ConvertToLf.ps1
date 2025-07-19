function Convert-ToLF {
    param (
        [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
        [string[]] $FilePaths
    )

    foreach ($file in $FilePaths) {
        if (-Not (Test-Path $file)) {
            Write-Warning "File not found: $file"
            continue
        }

        try {
            Write-Host "Converting: $file"

            $content = Get-Content $file -Raw
            $converted = $content -replace "`r`n", "`n" -replace "`r", "`n"

            # .NET方式でLF保存（BOMなしUTF-8）
            [System.IO.File]::WriteAllText($file, ($converted -join ""), [System.Text.Encoding]::UTF8)

            Write-Host "✓ Converted: $file"
        }
        catch {
            Write-Error ("Error processing {0}: {1}" -f $file, $_)
        }
    }
}
