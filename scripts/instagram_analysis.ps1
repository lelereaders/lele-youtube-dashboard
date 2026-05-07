param(
  [string]$EnvPath = ".env",
  [string]$OutputPath = "data/instagram-dashboard-data.js"
)

$ErrorActionPreference = "Stop"

function Import-DotEnv {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return }
  Get-Content -LiteralPath $Path -Encoding UTF8 | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith("#") -or -not $line.Contains("=")) { return }
    $parts = $line.Split("=", 2)
    $name = $parts[0].Trim()
    $value = $parts[1].Trim().Trim('"').Trim("'")
    [Environment]::SetEnvironmentVariable($name, $value, "Process")
  }
}

function Get-NumberOrZero {
  param($Value)
  if ($null -eq $Value -or $Value -eq "") { return [int64]0 }
  return [int64]$Value
}

function Clean-Text {
  param([string]$Text)
  if (-not $Text) { return "" }
  ($Text -replace "\s+", " ").Trim()
}

function Contains-Any {
  param(
    [string]$Text,
    [string[]]$Words
  )
  if (-not $Text) { return $false }
  $lower = $Text.ToLowerInvariant()
  foreach ($word in $Words) {
    if ($lower.Contains($word.ToLowerInvariant())) { return $true }
  }
  return $false
}

function Invoke-InstagramGet {
  param(
    [string]$Path,
    [hashtable]$Params = @{}
  )

  $token = [Environment]::GetEnvironmentVariable("INSTAGRAM_ACCESS_TOKEN", "Process")
  $version = [Environment]::GetEnvironmentVariable("INSTAGRAM_GRAPH_VERSION", "Process")
  if (-not $version) { $version = "v25.0" }
  if (-not $token) {
    throw "Missing INSTAGRAM_ACCESS_TOKEN. Add it to .env or GitHub Actions secrets."
  }

  $query = @{}
  foreach ($key in $Params.Keys) { $query[$key] = $Params[$key] }
  $query["access_token"] = $token

  $pairs = foreach ($key in $query.Keys) {
    "{0}={1}" -f [uri]::EscapeDataString($key), [uri]::EscapeDataString([string]$query[$key])
  }
  $uri = "https://graph.facebook.com/{0}/{1}?{2}" -f $version, $Path.TrimStart("/"), ($pairs -join "&")
  $debug = [Environment]::GetEnvironmentVariable("INSTAGRAM_DEBUG", "Process")
  if ($debug -eq "1") {
    $safeUri = $uri -replace "access_token=[^&]+", "access_token=REDACTED"
    Write-Host "Request: $safeUri"
  }

  try {
    Invoke-RestMethod -Uri $uri -Method Get
  }
  catch {
    $statusCode = $null
    $responseBody = ""
    if ($_.Exception.Response) {
      $statusCode = [int]$_.Exception.Response.StatusCode
      try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
          $reader = New-Object System.IO.StreamReader($stream)
          $responseBody = $reader.ReadToEnd()
          $reader.Close()
        }
      }
      catch {
        $responseBody = ""
      }
    }
    $message = $_.Exception.Message
    if ($responseBody) {
      throw "Instagram API request failed ($statusCode) at $Path. $message Response: $responseBody"
    }
    throw "Instagram API request failed ($statusCode) at $Path. $message"
  }
}

function Get-PagedData {
  param(
    [string]$Path,
    [hashtable]$Params = @{},
    [int]$MaxItems = 25
  )

  $items = New-Object System.Collections.Generic.List[object]
  $data = Invoke-InstagramGet -Path $Path -Params $Params
  foreach ($item in @($data.data)) {
    $items.Add($item)
    if ($MaxItems -gt 0 -and $items.Count -ge $MaxItems) { return $items }
  }

  while ($data.paging.next) {
    $data = Invoke-RestMethod -Uri $data.paging.next -Method Get
    foreach ($item in @($data.data)) {
      $items.Add($item)
      if ($MaxItems -gt 0 -and $items.Count -ge $MaxItems) { return $items }
    }
  }

  return $items
}

function Get-Theme {
  param([string]$Text)
  $themeMap = [ordered]@{
    "親子共讀" = @("共讀", "閱讀", "故事", "繪本", "read", "book")
    "孩子不說中文" = @("不說中文", "英文", "抗拒", "聽得懂", "不開口")
    "家庭語言" = @("母語", "廣東話", "台語", "華語", "中文", "home language")
    "免費資源" = @("活動紙", "printable", "freebie", "下載", "worksheet")
    "課程/社群興趣" = @("課程", "共學", "mastermind", "會員", "了解", "加入")
  }
  foreach ($theme in $themeMap.Keys) {
    if (Contains-Any -Text $Text -Words $themeMap[$theme]) { return $theme }
  }
  return "其他"
}

function Get-InsightMap {
  param([string]$MediaId)

  $metrics = [Environment]::GetEnvironmentVariable("INSTAGRAM_INSIGHT_METRICS", "Process")
  if (-not $metrics) { $metrics = "views,reach,saved,shares,total_interactions" }

  try {
    $insights = Invoke-InstagramGet -Path "$MediaId/insights" -Params @{ metric = $metrics }
    $map = [ordered]@{}
    foreach ($item in @($insights.data)) {
      $value = 0
      if ($item.values -and $item.values.Count -gt 0) {
        $value = Get-NumberOrZero $item.values[0].value
      }
      $map[$item.name] = $value
    }
    return $map
  }
  catch {
    return [ordered]@{}
  }
}

Import-DotEnv -Path $EnvPath

$igUserId = [Environment]::GetEnvironmentVariable("INSTAGRAM_USER_ID", "Process")
if (-not $igUserId) {
  throw "Missing INSTAGRAM_USER_ID. This should be the connected Instagram Business or Creator account ID."
}
if ($igUserId -match "[^0-9]") {
  throw "INSTAGRAM_USER_ID should be the numeric Instagram Business or Creator account ID, not an @username or profile URL."
}

$maxMediaValue = [Environment]::GetEnvironmentVariable("INSTAGRAM_MAX_MEDIA", "Process")
if (-not $maxMediaValue) { $maxMediaValue = "50" }
$maxCommentsValue = [Environment]::GetEnvironmentVariable("INSTAGRAM_MAX_COMMENTS_PER_MEDIA", "Process")
if (-not $maxCommentsValue) { $maxCommentsValue = "25" }
$maxMedia = [int]$maxMediaValue
$maxComments = [int]$maxCommentsValue

$profile = Invoke-InstagramGet -Path $igUserId -Params @{
  fields = "id,username,name,followers_count,media_count,profile_picture_url"
}

$mediaFields = "id,caption,media_type,media_product_type,media_url,thumbnail_url,permalink,timestamp,like_count,comments_count"
$mediaItems = Get-PagedData -Path "$igUserId/media" -Params @{
  fields = $mediaFields
  limit = [Math]::Min($maxMedia, 100)
} -MaxItems $maxMedia

$mediaRows = New-Object System.Collections.Generic.List[object]
$commentRows = New-Object System.Collections.Generic.List[object]
$themeCounts = @{}
$errors = @{}

foreach ($item in @($mediaItems.ToArray())) {
  $caption = Clean-Text $item.caption
  $theme = Get-Theme -Text $caption
  if (-not $themeCounts.ContainsKey($theme)) { $themeCounts[$theme] = 0 }
  $themeCounts[$theme]++

  $insightMap = Get-InsightMap -MediaId $item.id
  $views = if ($insightMap.Contains("views")) { $insightMap["views"] } else { 0 }
  $reach = if ($insightMap.Contains("reach")) { $insightMap["reach"] } else { 0 }
  $saved = if ($insightMap.Contains("saved")) { $insightMap["saved"] } else { 0 }
  $shares = if ($insightMap.Contains("shares")) { $insightMap["shares"] } else { 0 }
  $interactions = if ($insightMap.Contains("total_interactions")) { $insightMap["total_interactions"] } else { 0 }
  $likeCount = Get-NumberOrZero $item.like_count
  $commentCount = Get-NumberOrZero $item.comments_count

  $mediaRows.Add([pscustomobject][ordered]@{
    ID = $item.id
    Caption = $caption
    Type = $item.media_type
    Product = $item.media_product_type
    Published = if ($item.timestamp) { ([datetime]$item.timestamp).ToString("yyyy-MM-dd") } else { "" }
    URL = $item.permalink
    Image = if ($item.thumbnail_url) { $item.thumbnail_url } else { $item.media_url }
    Likes = $likeCount
    Comments = $commentCount
    Views = $views
    Reach = $reach
    Saved = $saved
    Shares = $shares
    Interactions = $interactions
    Theme = $theme
    "Engagement Rate" = if ($reach -gt 0) { [Math]::Round(($interactions / $reach), 4) } else { 0 }
  })

  try {
    $comments = Get-PagedData -Path "$($item.id)/comments" -Params @{
      fields = "id,text,username,timestamp,like_count"
      limit = [Math]::Min($maxComments, 50)
    } -MaxItems $maxComments
    foreach ($comment in @($comments.ToArray())) {
      $text = Clean-Text $comment.text
      $commentTheme = Get-Theme -Text $text
      if (-not $themeCounts.ContainsKey($commentTheme)) { $themeCounts[$commentTheme] = 0 }
      $themeCounts[$commentTheme]++
      $commentRows.Add([pscustomobject][ordered]@{
        Media = $caption
        "Media URL" = $item.permalink
        Username = $comment.username
        Published = if ($comment.timestamp) { ([datetime]$comment.timestamp).ToString("yyyy-MM-dd") } else { "" }
        Likes = Get-NumberOrZero $comment.like_count
        Comment = $text
        Category = $commentTheme
        "Response Guidance" = if ($commentTheme -eq "課程/社群興趣") { "可溫柔接住需求，邀請私訊或到 landing form 領取對應資源。" } elseif ($commentTheme -eq "免費資源") { "回覆下載方式，並引導加入 Kit freebie sequence。" } else { "先肯定家庭經驗，再邀請分享孩子年齡與家中語言狀況。" }
      })
    }
  }
  catch {
    $errors[$item.id] = $_.Exception.Message
  }
}

$mediaArray = @($mediaRows.ToArray())
$commentsArray = @($commentRows.ToArray())
$totalLikes = @($mediaArray | Measure-Object -Property Likes -Sum).Sum
$totalComments = @($mediaArray | Measure-Object -Property Comments -Sum).Sum
$totalViews = @($mediaArray | Measure-Object -Property Views -Sum).Sum
$totalReach = @($mediaArray | Measure-Object -Property Reach -Sum).Sum
$totalInteractions = @($mediaArray | Measure-Object -Property Interactions -Sum).Sum

$themeRows = @($themeCounts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
  [pscustomobject][ordered]@{
    Theme = $_.Key
    Count = $_.Value
    Method = "從貼文 caption 與留言關鍵詞自動標記"
  }
})

$payload = [pscustomobject][ordered]@{
  generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm")
  source = "Instagram Graph API"
  profile = [pscustomobject][ordered]@{
    id = $profile.id
    username = $profile.username
    name = $profile.name
    followers = Get-NumberOrZero $profile.followers_count
    mediaCount = Get-NumberOrZero $profile.media_count
    picture = $profile.profile_picture_url
  }
  dashboard = [pscustomobject][ordered]@{
    metrics = [ordered]@{
      "Posts analyzed" = $mediaArray.Count
      "Followers" = Get-NumberOrZero $profile.followers_count
      "Likes total" = Get-NumberOrZero $totalLikes
      "Comments total" = Get-NumberOrZero $totalComments
      "Views total" = Get-NumberOrZero $totalViews
      "Reach total" = Get-NumberOrZero $totalReach
      "Interactions total" = Get-NumberOrZero $totalInteractions
    }
  }
  media = $mediaArray
  comments = $commentsArray
  themes = $themeRows
  actionIdeas = @(
    [pscustomobject][ordered]@{ Type = "Reels 題目"; Recommendation = "把最高互動主題延伸成 3 支短影片：家中語言、孩子不說中文、10 分鐘共讀"; Priority = "高" },
    [pscustomobject][ordered]@{ Type = "Kit CTA"; Recommendation = "高互動貼文置頂留言：留言「共讀」或到 landing form 領 10 分鐘親子共讀開始包"; Priority = "高" },
    [pscustomobject][ordered]@{ Type = "Claude Team"; Recommendation = "LUNA 將高互動 caption 改寫成電子報；芳芳把留言問題整理成 Le Le Talk 開場問題"; Priority = "中" }
  )
  automation = [pscustomobject][ordered]@{
    tags = @("IG-engaged-parent", "IG-reels-coreading", "IG-comment-family-language", "IG-clicked-freebie")
    segments = @("Instagram 高互動家長", "共讀興趣家長", "家庭語言/廣東話/台語家庭", "需要低壓中文方法的海外家庭")
    sequence = "Instagram freebie nurture：留言互動故事 -> 10 分鐘共讀開始包 -> Mastermind / 閱讀挑戰邀請"
    landingForm = "Instagram 專屬：孩子不愛說中文？領一份 10 分鐘親子共讀開始包"
    cta = "留言「共讀」告訴我孩子年齡和家中最常用語言，我把適合你家的開始方式整理給你。"
  }
  errors = $errors
}

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$resolvedOutputPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
  $OutputPath
} else {
  Join-Path $root $OutputPath
}
$outputDir = Split-Path -Parent $resolvedOutputPath
if (!(Test-Path -LiteralPath $outputDir)) {
  New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$json = $payload | ConvertTo-Json -Depth 20
"window.LELE_INSTAGRAM_DASHBOARD = $json;" | Set-Content -LiteralPath $resolvedOutputPath -Encoding UTF8
Write-Host "Wrote $resolvedOutputPath"
