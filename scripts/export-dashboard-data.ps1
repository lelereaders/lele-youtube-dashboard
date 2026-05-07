param(
  [string]$WorkbookPath = "youtube_reports/YouTube_Comment_Insights_latest.xlsx",
  [string]$OutputPath = "data\youtube-dashboard-data.js"
)

$ErrorActionPreference = "Stop"

function Get-ColumnName {
  param([string]$CellRef)
  return ($CellRef -replace '\d', '')
}

function Get-CellValue {
  param($Cell, $NamespaceManager)

  $inline = $Cell.SelectSingleNode("x:is/x:t", $NamespaceManager)
  if ($inline) {
    return $inline.InnerText
  }

  $formula = $Cell.SelectSingleNode("x:f", $NamespaceManager)
  if ($formula -and $formula.InnerText -match 'HYPERLINK\("([^"]+)"') {
    return $matches[1]
  }

  $value = $Cell.SelectSingleNode("x:v", $NamespaceManager)
  if ($value) {
    $text = $value.InnerText
    $number = 0.0
    if ([double]::TryParse($text, [ref]$number)) {
      if ($number % 1 -eq 0) {
        return [int64]$number
      }
      return $number
    }
    return $text
  }

  return ""
}

function Read-Sheet {
  param([string]$SheetPath)

  [xml]$xml = Get-Content -LiteralPath $SheetPath -Raw
  $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
  $ns.AddNamespace("x", "http://schemas.openxmlformats.org/spreadsheetml/2006/main")

  $rows = @()
  foreach ($row in $xml.SelectNodes("//x:sheetData/x:row", $ns)) {
    $rowData = [ordered]@{}
    foreach ($cell in $row.SelectNodes("x:c", $ns)) {
      $column = Get-ColumnName $cell.r
      $rowData[$column] = Get-CellValue $cell $ns
    }
    $rows += [pscustomobject]$rowData
  }
  return $rows
}

function Convert-Table {
  param($Rows)

  if ($Rows.Count -lt 2) {
    return @()
  }

  $header = $Rows[0]
  $columns = $header.PSObject.Properties | ForEach-Object {
    [pscustomobject]@{ Column = $_.Name; Name = [string]$_.Value }
  } | Where-Object { $_.Name -ne "" }

  $items = @()
  foreach ($row in ($Rows | Select-Object -Skip 1)) {
    $item = [ordered]@{}
    $hasValue = $false

    foreach ($column in $columns) {
      $value = ""
      if ($row.PSObject.Properties[$column.Column]) {
        $value = $row.PSObject.Properties[$column.Column].Value
      }
      if ($value -ne "") {
        $hasValue = $true
      }
      $item[$column.Name] = $value
    }

    if ($hasValue) {
      $items += [pscustomobject]$item
    }
  }

  return $items
}

function Convert-Dashboard {
  param($Rows)

  $metrics = [ordered]@{}
  $topVideos = @()
  $formats = @()
  $section = "metrics"

  foreach ($row in $Rows) {
    $a = if ($row.PSObject.Properties["A"]) { [string]$row.A } else { "" }
    $b = if ($row.PSObject.Properties["B"]) { $row.B } else { "" }

    if ($a -eq "Metric" -or $a -eq "" -or $a -eq "A") {
      continue
    }
    if ($a -eq "Top Videos by Views") {
      $section = "top"
      continue
    }
    if ($a -eq "Rank") {
      continue
    }
    if ($a -eq "Format") {
      $section = "formats"
      continue
    }

    if ($section -eq "metrics") {
      $metrics[$a] = $b
    } elseif ($section -eq "top") {
      $topVideos += [pscustomobject][ordered]@{
        rank = $row.A
        title = $row.B
        views = $row.C
        likes = $row.D
        comments = $row.E
        url = $row.F
      }
    } elseif ($section -eq "formats") {
      $formats += [pscustomobject][ordered]@{
        format = $row.A
        count = $row.B
        views = $row.C
        avgViews = $row.D
      }
    }
  }

  return [pscustomobject][ordered]@{
    metrics = $metrics
    topVideos = $topVideos
    formats = $formats
  }
}

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$resolvedWorkbookPath = if ([System.IO.Path]::IsPathRooted($WorkbookPath)) {
  $WorkbookPath
} else {
  Join-Path $root $WorkbookPath
}

if (!(Test-Path -LiteralPath $resolvedWorkbookPath)) {
  throw "Workbook not found: $resolvedWorkbookPath"
}

$resolvedOutputPath = Join-Path $root $OutputPath
$outputDir = Split-Path -Parent $resolvedOutputPath
if (!(Test-Path -LiteralPath $outputDir)) {
  New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$temp = Join-Path $root ".xlsx_extract"
if (Test-Path -LiteralPath $temp) {
  Remove-Item -LiteralPath $temp -Recurse -Force
}
New-Item -ItemType Directory -Path $temp | Out-Null

$zipPath = Join-Path $temp "workbook.zip"
Copy-Item -LiteralPath $resolvedWorkbookPath -Destination $zipPath
Expand-Archive -LiteralPath $zipPath -DestinationPath $temp -Force

$sheetRoot = Join-Path $temp "xl/worksheets"
$dashboardRows = Read-Sheet (Join-Path $sheetRoot "sheet1.xml")
$videosRows = Read-Sheet (Join-Path $sheetRoot "sheet2.xml")
$commentsRows = Read-Sheet (Join-Path $sheetRoot "sheet3.xml")
$themesRows = Read-Sheet (Join-Path $sheetRoot "sheet4.xml")
$ideasRows = Read-Sheet (Join-Path $sheetRoot "sheet5.xml")

$payload = [pscustomobject][ordered]@{
  generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm")
  sourceWorkbook = (Split-Path -Leaf $resolvedWorkbookPath)
  dashboard = Convert-Dashboard $dashboardRows
  videos = Convert-Table $videosRows
  comments = Convert-Table $commentsRows
  themes = Convert-Table $themesRows
  actionIdeas = Convert-Table $ideasRows
}

$json = $payload | ConvertTo-Json -Depth 10
"window.LELE_YOUTUBE_DASHBOARD = $json;" | Set-Content -LiteralPath $resolvedOutputPath -Encoding UTF8

Remove-Item -LiteralPath $temp -Recurse -Force
Write-Host "Wrote $resolvedOutputPath"
