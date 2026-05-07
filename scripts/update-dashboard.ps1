param(
  [string]$OutputDir = "youtube_reports",
  [string]$WorkbookPath = "youtube_reports/YouTube_Comment_Insights_latest.xlsx"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$reportsDir = Join-Path $root $OutputDir
$resolvedWorkbookPath = if ([System.IO.Path]::IsPathRooted($WorkbookPath)) {
  $WorkbookPath
} else {
  Join-Path $root $WorkbookPath
}

New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null

$youtubeScript = Join-Path $root "scripts/youtube_analysis.ps1"
$xlsxScript = Join-Path $root "scripts/build_youtube_comment_insights_xlsx.ps1"
$exportScript = Join-Path $root "scripts/export-dashboard-data.ps1"

Write-Host "Fetching latest YouTube videos and comments..."
& $youtubeScript -EnvPath (Join-Path $root ".env") -OutputDir $reportsDir

$latestVideosCsv = Get-ChildItem -LiteralPath $reportsDir -Filter "videos_*.csv" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1
$latestCommentsCsv = Get-ChildItem -LiteralPath $reportsDir -Filter "comments_*.csv" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if (-not $latestVideosCsv) {
  throw "No videos CSV was generated."
}
if (-not $latestCommentsCsv) {
  throw "No comments CSV was generated."
}

Write-Host "Building workbook..."
& $xlsxScript -VideosCsv $latestVideosCsv.FullName -CommentsCsv $latestCommentsCsv.FullName -OutputXlsx $WorkbookPath


Write-Host "Exporting dashboard data..."
& $exportScript -WorkbookPath $resolvedWorkbookPath -OutputPath "data/youtube-dashboard-data.js"

Write-Host "Dashboard updated."
