param(
  [string]$VideosCsv = "./youtube_reports/videos_20260506_173527.csv",
  [string]$CommentsCsv = "./youtube_reports/comments_20260506_173527.csv",
  [string]$OutputXlsx = "./youtube_reports/YouTube_Comment_Insights_20260506.xlsx"
)

$ErrorActionPreference = "Stop"

function To-Int64 {
  param($Value)
  if ($null -eq $Value -or $Value -eq "") { return [int64]0 }
  return [int64]$Value
}

function Xml-Escape {
  param($Value)
  if ($null -eq $Value) { return "" }
  return [System.Security.SecurityElement]::Escape([string]$Value)
}

function Formula-Escape {
  param([string]$Value)
  return ($Value -replace '"', '""')
}

function Get-ColName {
  param([int]$Index)
  $name = ""
  while ($Index -gt 0) {
    $mod = ($Index - 1) % 26
    $name = [char](65 + $mod) + $name
    $Index = [math]::Floor(($Index - $mod) / 26)
  }
  return $name
}

function Contains-Any {
  param([string]$Text, [string[]]$Words)
  $lower = ([string]$Text).ToLowerInvariant()
  foreach ($word in $Words) {
    if ($lower.Contains($word.ToLowerInvariant())) { return $true }
  }
  return $false
}

function Is-Short {
  param([string]$Title)
  if (-not $Title) { return $false }
  return $Title.ToLowerInvariant().Contains("#shorts")
}

function Get-CommentCategory {
  param([string]$Text)
  if (Contains-Any $Text @("台独", "台獨", "去中國化", "政治", "文化大革命", "cancel")) { return "政治/爭議" }
  if (Contains-Any $Text @("台語", "閩南語", "母語", "華語", "中文", "廣東話", "粤語", "粵語")) { return "家庭語言" }
  if (Contains-Any $Text @("學", "孩子", "小孩", "共學", "閱讀", "讀")) { return "學習/共讀" }
  return "其他"
}

function Get-ResponseGuidance {
  param([string]$Category)
  switch ($Category) {
    "政治/爭議" { return "低衝突回覆：感謝分享，拉回家庭語言與親子連結，不辯政治立場。" }
    "家庭語言" { return "可回覆：肯定每個家庭的語言選擇，邀請分享家中使用語言的故事。" }
    "學習/共讀" { return "可回覆：接住家長經驗，補一句每天一點點、陪伴比完美重要。" }
    default { return "可簡短感謝，觀察是否能延伸成下一支內容題材。" }
  }
}

function Get-ThemeTags {
  param([string]$Text)
  $tags = New-Object System.Collections.Generic.List[string]
  $themes = [ordered]@{
    "孩子只說英文" = @("英文", "只說英文", "只说英文", "不說中文", "不说中文")
    "太晚開始" = @("太晚", "七歲", "七岁", "八歲", "八岁", "來得及", "来得及")
    "父母中文不夠好" = @("不會中文", "不会中文", "中文不好", "不是母語", "不是母语", "發音", "发音")
    "共讀與閱讀" = @("共讀", "共读", "閱讀", "阅读", "讀書", "读书", "繪本", "绘本")
    "點讀筆與工具" = @("點讀筆", "点读笔", "教材", "樂樂", "乐乐", "Lola")
    "注音拼音" = @("注音", "拼音", "zhuyin", "pinyin")
    "海外環境" = @("海外", "美國", "美国", "澳洲", "英國", "英国", "加拿大", "沒有環境", "没有环境")
    "家庭語言" = @("母語", "母语", "台語", "台语", "粵語", "粤语", "廣東話", "广东话", "華語", "中文", "閩南語")
  }
  foreach ($theme in $themes.Keys) {
    if (Contains-Any $Text $themes[$theme]) { $tags.Add($theme) }
  }
  if ($tags.Count -eq 0) { return "未分類" }
  return ($tags.ToArray() -join ", ")
}

function Build-SheetXml {
  param(
    [string[]]$Headers,
    [object[]]$Rows,
    [int[]]$NumberCols = @(),
    [int[]]$PercentCols = @(),
    [int[]]$HyperlinkCols = @(),
    [hashtable]$Widths = @{}
  )
  $colCount = $Headers.Count
  $rowCount = $Rows.Count + 1
  $lastRef = "$(Get-ColName $colCount)$rowCount"
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
  [void]$sb.Append('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
  [void]$sb.Append('<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>')
  if ($Widths.Count -gt 0) {
    [void]$sb.Append('<cols>')
    foreach ($key in $Widths.Keys) {
      [void]$sb.Append(('<col min="{0}" max="{0}" width="{1}" customWidth="1"/>' -f $key, $Widths[$key]))
    }
    [void]$sb.Append('</cols>')
  }
  [void]$sb.Append('<sheetData>')
  [void]$sb.Append('<row r="1">')
  for ($c = 1; $c -le $colCount; $c++) {
    $ref = "$(Get-ColName $c)1"
    [void]$sb.Append(('<c r="{0}" s="1" t="inlineStr"><is><t>{1}</t></is></c>' -f $ref, (Xml-Escape $Headers[$c - 1])))
  }
  [void]$sb.Append('</row>')
  for ($r = 0; $r -lt $Rows.Count; $r++) {
    $excelRow = $r + 2
    [void]$sb.Append(('<row r="{0}">' -f $excelRow))
    $row = $Rows[$r]
    for ($c = 1; $c -le $colCount; $c++) {
      $value = $row[$c - 1]
      $valueText = if ($null -eq $value) { "" } else { [string]$value }
      $ref = "$(Get-ColName $c)$excelRow"
      if ($HyperlinkCols -contains $c -and $valueText.StartsWith("http")) {
        $url = Formula-Escape $valueText
        $formula = Xml-Escape ('HYPERLINK("' + $url + '","' + $url + '")')
        [void]$sb.Append(('<c r="{0}" s="4"><f>{1}</f></c>' -f $ref, $formula))
      }
      elseif ($PercentCols -contains $c) {
        [void]$sb.Append(('<c r="{0}" s="3"><v>{1}</v></c>' -f $ref, ([string]$value)))
      }
      elseif ($NumberCols -contains $c) {
        [void]$sb.Append(('<c r="{0}" s="2"><v>{1}</v></c>' -f $ref, ([string]$value)))
      }
      else {
        [void]$sb.Append(('<c r="{0}" t="inlineStr"><is><t>{1}</t></is></c>' -f $ref, (Xml-Escape $valueText)))
      }
    }
    [void]$sb.Append('</row>')
  }
  [void]$sb.Append('</sheetData>')
  [void]$sb.Append(('<autoFilter ref="A1:{0}"/>' -f $lastRef))
  [void]$sb.Append('</worksheet>')
  return $sb.ToString()
}

if (-not (Test-Path -LiteralPath $VideosCsv)) { throw "Missing videos CSV: $VideosCsv" }
if (-not (Test-Path -LiteralPath $CommentsCsv)) { throw "Missing comments CSV: $CommentsCsv" }

$videos = @(Import-Csv -LiteralPath $VideosCsv)
$comments = @(Import-Csv -LiteralPath $CommentsCsv)
$videoById = @{}
foreach ($v in $videos) { $videoById[$v.video_id] = $v }

$videoRows = New-Object System.Collections.Generic.List[object]
foreach ($v in $videos) {
  $views = To-Int64 $v.views
  $likes = To-Int64 $v.likes
  $commentCount = To-Int64 $v.comments
  $engagement = if ($views -gt 0) { [math]::Round((($likes + $commentCount) / $views), 4) } else { 0 }
  $videoRows.Add([object[]]@($v.video_id, $v.title, ([string]$v.published_at).Substring(0, 10), $v.url, $views, $likes, $commentCount, $engagement, $(if (Is-Short $v.title) { "Yes" } else { "No" }))) | Out-Null
}

$commentRows = New-Object System.Collections.Generic.List[object]
foreach ($c in $comments) {
  $video = $videoById[$c.video_id]
  $category = Get-CommentCategory $c.text
  $commentRows.Add([object[]]@($c.video_id, $video.title, $video.url, $c.author, ([string]$c.published_at).Substring(0, 10), (To-Int64 $c.like_count), $c.text, $(if ([string]$c.is_reply -eq "True") { "Yes" } else { "No" }), $category, (Get-ThemeTags $c.text), (Get-ResponseGuidance $category))) | Out-Null
}

$themeCounts = @{}
foreach ($row in $commentRows) {
  $tagText = [string]$row[9]
  if (-not $tagText) { continue }
  foreach ($rawTag in $tagText.Split(",")) {
    $tag = $rawTag.Trim()
    if (-not $tag -or $tag -eq "未分類") { continue }
    if (-not $themeCounts.ContainsKey($tag)) { $themeCounts[$tag] = 0 }
    $themeCounts[$tag]++
  }
}
$themeRows = New-Object System.Collections.Generic.List[object]
foreach ($entry in ($themeCounts.GetEnumerator() | Sort-Object Value -Descending)) {
  $themeRows.Add([object[]]@($entry.Key, $entry.Value, "從留言文字關鍵詞自動標記")) | Out-Null
}

$totalViews = ($videos | ForEach-Object { To-Int64 $_.views } | Measure-Object -Sum).Sum
$totalLikes = ($videos | ForEach-Object { To-Int64 $_.likes } | Measure-Object -Sum).Sum
$totalComments = ($videos | ForEach-Object { To-Int64 $_.comments } | Measure-Object -Sum).Sum
$channelSubscribers = if ($videos.Count -gt 0 -and $videos[0].PSObject.Properties["channel_subscribers"]) { To-Int64 $videos[0].channel_subscribers } else { 0 }
$videosWithComments = @($videos | Where-Object { (To-Int64 $_.comments) -gt 0 }).Count
$shortVideos = @($videos | Where-Object { Is-Short $_.title })
$longVideos = @($videos | Where-Object { -not (Is-Short $_.title) })
$topVideos = @($videos | Sort-Object { To-Int64 $_.views } -Descending | Select-Object -First 10)
$shortViews = ($shortVideos | ForEach-Object { To-Int64 $_.views } | Measure-Object -Sum).Sum
$longViews = ($longVideos | ForEach-Object { To-Int64 $_.views } | Measure-Object -Sum).Sum

$dashboardRows = New-Object System.Collections.Generic.List[object]
$dashboardRows.Add([object[]]@("Metric", "Value", "Notes", "", "", "")) | Out-Null
$dashboardRows.Add([object[]]@("Videos analyzed", $videos.Count, "Latest complete local export", "", "", "")) | Out-Null
$dashboardRows.Add([object[]]@("Channel subscribers", $channelSubscribers, "Public YouTube channel subscriber count", "", "", "")) | Out-Null
$dashboardRows.Add([object[]]@("Comments fetched", $comments.Count, "Public comments from exported videos", "", "", "")) | Out-Null
$dashboardRows.Add([object[]]@("Public views total", $totalViews, "", "", "", "")) | Out-Null
$dashboardRows.Add([object[]]@("Public likes total", $totalLikes, "", "", "", "")) | Out-Null
$dashboardRows.Add([object[]]@("Public comments total", $totalComments, "", "", "", "")) | Out-Null
$dashboardRows.Add([object[]]@("Videos with comments", $videosWithComments, "", "", "", "")) | Out-Null
$dashboardRows.Add([object[]]@("Shorts count", $shortVideos.Count, "", "", "", "")) | Out-Null
$dashboardRows.Add([object[]]@("Long-form count", $longVideos.Count, "", "", "", "")) | Out-Null
$dashboardRows.Add([object[]]@("", "", "", "", "", "")) | Out-Null
$dashboardRows.Add([object[]]@("Top Videos by Views", "", "", "", "", "")) | Out-Null
$dashboardRows.Add([object[]]@("Rank", "Title", "Views", "Likes", "Comments", "URL")) | Out-Null
$rank = 1
foreach ($v in $topVideos) {
  $dashboardRows.Add([object[]]@($rank, $v.title, (To-Int64 $v.views), (To-Int64 $v.likes), (To-Int64 $v.comments), $v.url)) | Out-Null
  $rank++
}
$dashboardRows.Add([object[]]@("", "", "", "", "", "")) | Out-Null
$dashboardRows.Add([object[]]@("Format", "Count", "Views", "Avg views", "", "")) | Out-Null
$dashboardRows.Add([object[]]@("Shorts", $shortVideos.Count, $shortViews, $(if ($shortVideos.Count -gt 0) { [math]::Round($shortViews / $shortVideos.Count, 1) } else { 0 }), "", "")) | Out-Null
$dashboardRows.Add([object[]]@("Long-form", $longVideos.Count, $longViews, $(if ($longVideos.Count -gt 0) { [math]::Round($longViews / $longVideos.Count, 1) } else { 0 }), "", "")) | Out-Null

$actionRows = New-Object System.Collections.Generic.List[object]
$actionRows.Add([object[]]@("下一支 Shorts 題目", "「為什麼孩子一上學就不說中文？」延伸成安全感與家庭語言系列", "Shorts 中雙語流失、母語身份題材表現較好", "高")) | Out-Null
$actionRows.Add([object[]]@("留言回覆角度", "遇到台語/華語/中文命名爭議時，回到『每個家庭都在找回自己的連結』", "留言中政治/語言身份爭議明顯", "高")) | Out-Null
$actionRows.Add([object[]]@("內容系列", "做 3 支：母語不是政治、母語是家的聲音、孩子需要聽見家人的語言", "家庭語言是留言主題最高", "中")) | Out-Null
$actionRows.Add([object[]]@("影片優化", "把 Untitled Shorts 補上明確標題，避免後續分析與觀眾理解成本", "最近 Shorts 有 Untitled title", "中")) | Out-Null
$actionRows.Add([object[]]@("CTA", "在高觀看 Shorts 置頂留言引導：留言『GROUP』或加入 LINE/電子報", "高觀看影片留言仍少，需明確互動指令", "中")) | Out-Null

$sheets = @(
  @{ Name = "Dashboard"; Headers = @("A", "B", "C", "D", "E", "F"); Rows = $dashboardRows; NumberCols = @(1,2,3,4,5); PercentCols = @(); HyperlinkCols = @(6); Widths = @{1=24;2=70;3=18;4=12;5=12;6=45} }
  @{ Name = "Videos"; Headers = @("Video ID", "Title", "Published", "URL", "Views", "Likes", "Comments", "Engagement Rate", "Shorts"); Rows = $videoRows; NumberCols = @(5,6,7); PercentCols = @(8); HyperlinkCols = @(4); Widths = @{1=16;2=80;3=14;4=45;5=12;6=12;7=12;8=16;9=10} }
  @{ Name = "Comments"; Headers = @("Video ID", "Video Title", "Video URL", "Author", "Published", "Likes", "Comment", "Reply", "Category", "Theme Tags", "Response Guidance"); Rows = $commentRows; NumberCols = @(6); PercentCols = @(); HyperlinkCols = @(3); Widths = @{1=16;2=65;3=45;4=18;5=14;6=10;7=80;8=10;9=16;10=28;11=55} }
  @{ Name = "Themes"; Headers = @("Theme", "Comment Count", "Method"); Rows = $themeRows; NumberCols = @(2); PercentCols = @(); HyperlinkCols = @(); Widths = @{1=24;2=16;3=36} }
  @{ Name = "Action Ideas"; Headers = @("Type", "Recommendation", "Why", "Priority"); Rows = $actionRows; NumberCols = @(); PercentCols = @(); HyperlinkCols = @(); Widths = @{1=22;2=70;3=55;4=12} }
)

$tempRoot = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { [System.IO.Path]::GetTempPath() }
$temp = Join-Path $tempRoot ("youtube_xlsx_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $temp | Out-Null
New-Item -ItemType Directory -Path (Join-Path $temp "_rels") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $temp "xl") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $temp "xl/_rels") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $temp "xl/worksheets") | Out-Null

$overrides = ""
for ($i = 1; $i -le $sheets.Count; $i++) {
  $overrides += '<Override PartName="/xl/worksheets/sheet' + $i + '.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
}
$contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' + $overrides + '</Types>'
Set-Content -LiteralPath (Join-Path $temp "[Content_Types].xml") -Encoding UTF8 -Value $contentTypes
Set-Content -LiteralPath (Join-Path $temp "_rels/.rels") -Encoding UTF8 -Value '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>'

$sheetEntries = ""
$rels = ""
for ($i = 1; $i -le $sheets.Count; $i++) {
  $sheetName = Xml-Escape $sheets[$i - 1].Name
  $sheetEntries += '<sheet name="' + $sheetName + '" sheetId="' + $i + '" r:id="rId' + $i + '"/>'
  $rels += '<Relationship Id="rId' + $i + '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet' + $i + '.xml"/>'
}
$rels += '<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
Set-Content -LiteralPath (Join-Path $temp "xl/workbook.xml") -Encoding UTF8 -Value ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>' + $sheetEntries + '</sheets></workbook>')
Set-Content -LiteralPath (Join-Path $temp "xl/_rels/workbook.xml.rels") -Encoding UTF8 -Value ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' + $rels + '</Relationships>')
Set-Content -LiteralPath (Join-Path $temp "xl/styles.xml") -Encoding UTF8 -Value '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><numFmts count="1"><numFmt numFmtId="164" formatCode="0.00%"/></numFmts><fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts><fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FFD9EAF7"/><bgColor indexed="64"/></patternFill></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="5"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/><xf numFmtId="3" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/><xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs></styleSheet>'

for ($i = 1; $i -le $sheets.Count; $i++) {
  $s = $sheets[$i - 1]
  $xml = Build-SheetXml $s.Headers $s.Rows $s.NumberCols $s.PercentCols $s.HyperlinkCols $s.Widths
  Set-Content -LiteralPath (Join-Path $temp ("xl/worksheets/sheet" + $i + ".xml")) -Encoding UTF8 -Value $xml
}

$fullOutput = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputXlsx))
if (Test-Path -LiteralPath $fullOutput) { Remove-Item -LiteralPath $fullOutput -Force }
$zipOutput = [System.IO.Path]::ChangeExtension($fullOutput, ".zip")
if (Test-Path -LiteralPath $zipOutput) { Remove-Item -LiteralPath $zipOutput -Force }
Compress-Archive -Path (Join-Path $temp "*") -DestinationPath $zipOutput -Force
Move-Item -LiteralPath $zipOutput -Destination $fullOutput -Force
Remove-Item -LiteralPath $temp -Recurse -Force
Write-Host "Done. Workbook: $fullOutput"





