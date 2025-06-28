# 環境変数設定
$env:TEST_ENV = 'テスト環境変数'
# 通常変数設定
$myVariable = 'テスト変数'
# 関数定義
function Test-AllTypes { Write-Host '関数・変数・環境変数すべて適用!' -ForegroundColor Magenta }
