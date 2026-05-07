param(
  [string]$EnvPath = ".env",
  [string]$OutputDir = "youtube_reports"
)

$ErrorActionPreference = "Stop"
$ApiBase = "https://www.googleapis.com/youtube/v3"

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

function Invoke-YouTubeGet {
  param(
    [string]$Endpoint,
    [hashtable]$Params
  )
  $apiKey = [Environment]::GetEnvironmentVariable("YOUTUBE_API_KEY", "Process")
  if (-not $apiKey) {
    throw "Missing YOUTUBE_API_KEY. Copy .env.example to .env and fill in your key."
  }

  $query = @{}
  foreach ($key in $Params.Keys) { $query[$key] = $Params[$key] }
  $query["key"] = $apiKey

  $pairs = foreach ($key in $query.Keys) {
    "{0}={1}" -f [uri]::EscapeDataString($key), [uri]::EscapeDataString([string]$query[$key])
  }
  $uri = "{0}/{1}?{2}" -f $ApiBase, $Endpoint, ($pairs -join "&")
  $debug = [Environment]::GetEnvironmentVariable("YOUTUBE_DEBUG", "Process")
  if ($debug -eq "1") {
    $safeUri = $uri -replace "key=[^&]+", "key=REDACTED"
    Write-Host "Request: $safeUri"
  }
  try {
    Invoke-RestMethod -Uri $uri -Method Get
  }
  catch {
    $statusCode = $null
    if ($_.Exception.Response) {
      $statusCode = [int]$_.Exception.Response.StatusCode
    }
    $message = $_.Exception.Message
    throw "YouTube API request failed ($statusCode) at $Endpoint. $message"
  }
}

function Get-YouTubePaged {
  param(
    [string]$Endpoint,
    [hashtable]$Params,
    [int]$MaxItems = 0
  )
  $items = New-Object System.Collections.Generic.List[object]
  $pageToken = $null

  while ($true) {
    $query = @{}
    foreach ($key in $Params.Keys) { $query[$key] = $Params[$key] }
    if ($pageToken) { $query["pageToken"] = $pageToken }

    $data = Invoke-YouTubeGet -Endpoint $Endpoint -Params $query
    foreach ($item in @($data.items)) {
      $items.Add($item)
      if ($MaxItems -gt 0 -and $items.Count -ge $MaxItems) { return $items }
    }
    if (-not $data.nextPageToken) { return $items }
    $pageToken = $data.nextPageToken
  }
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
  $lower = $Text.ToLowerInvariant()
  foreach ($word in $Words) {
    if ($lower.Contains($word.ToLowerInvariant())) { return $true }
  }
  return $false
}

function Get-NumberOrZero {
  param($Value)
  if ($null -eq $Value -or $Value -eq "") { return [int64]0 }
  return [int64]$Value
}

function Get-VideoRow {
  param(
    $Video,
    [int64]$SubscriberCount = 0
  )
  [pscustomobject]@{
    video_id            = $Video.id
    title               = $Video.snippet.title
    published_at        = $Video.snippet.publishedAt
    url                 = "https://www.youtube.com/watch?v=$($Video.id)"
    views               = Get-NumberOrZero $Video.statistics.viewCount
    likes               = Get-NumberOrZero $Video.statistics.likeCount
    comments            = Get-NumberOrZero $Video.statistics.commentCount
    channel_subscribers = $SubscriberCount
  }
}

function Get-TopComments {
  param(
    [object[]]$Comments,
    [int]$Limit = 5
  )
  @($Comments | Sort-Object -Property @{Expression = "like_count"; Descending = $true}, @{Expression = "published_at"; Descending = $true} | Select-Object -First $Limit)
}

function Resolve-ChannelInput {
  param([string]$InputValue)

  $value = $InputValue.Trim()
  if ($value -match "youtube\.com/channel/([^/?#]+)") {
    return @{ Mode = "id"; Value = $matches[1] }
  }
  if ($value -match "youtube\.com/@([^/?#]+)") {
    return @{ Mode = "handle"; Value = "@$($matches[1])" }
  }
  if ($value.StartsWith("@")) {
    return @{ Mode = "handle"; Value = $value }
  }
  if ($value.StartsWith("UC") -and $value.Length -ge 20) {
    return @{ Mode = "id"; Value = $value }
  }
  return @{ Mode = "handle"; Value = $value }
}

function Get-ChannelByInput {
  param([string]$InputValue)

  $resolved = Resolve-ChannelInput -InputValue $InputValue
  if ($resolved.Mode -eq "handle") {
    return Invoke-YouTubeGet -Endpoint "channels" -Params @{
      part       = "contentDetails,snippet,statistics"
      forHandle  = $resolved.Value
      maxResults = 1
    }
  }

  return Invoke-YouTubeGet -Endpoint "channels" -Params @{
    part       = "contentDetails,snippet,statistics"
    id         = $resolved.Value
    maxResults = 1
  }
}

Import-DotEnv -Path $EnvPath

$channelId = [Environment]::GetEnvironmentVariable("YOUTUBE_CHANNEL_ID", "Process")
if (-not $channelId) {
  throw "Missing YOUTUBE_CHANNEL_ID. Add it to .env."
}

$maxVideosValue = [Environment]::GetEnvironmentVariable("YOUTUBE_MAX_VIDEOS", "Process")
if (-not $maxVideosValue) { $maxVideosValue = "10" }
$maxCommentsValue = [Environment]::GetEnvironmentVariable("YOUTUBE_MAX_COMMENTS_PER_VIDEO", "Process")
if (-not $maxCommentsValue) { $maxCommentsValue = "100" }
$maxVideos = [int]$maxVideosValue
$maxComments = [int]$maxCommentsValue

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$channelData = Get-ChannelByInput -InputValue $channelId

if (-not $channelData.items -or $channelData.items.Count -eq 0) {
  throw "No channel found for YOUTUBE_CHANNEL_ID=$channelId. Use a channel ID like UC..., a handle like @YourHandle, or a channel URL like https://www.youtube.com/@YourHandle."
}

$channel = $channelData.items[0]
$uploadsPlaylistId = $channel.contentDetails.relatedPlaylists.uploads
$channelSubscribers = Get-NumberOrZero $channel.statistics.subscriberCount

$playlistItems = Get-YouTubePaged -Endpoint "playlistItems" -Params @{
  part       = "snippet,contentDetails"
  playlistId = $uploadsPlaylistId
  maxResults = [Math]::Min($maxVideos, 50)
} -MaxItems $maxVideos

$videoIds = @($playlistItems | ForEach-Object { $_.contentDetails.videoId })
$videos = New-Object System.Collections.Generic.List[object]
for ($i = 0; $i -lt $videoIds.Count; $i += 50) {
  $batch = @($videoIds[$i..([Math]::Min($i + 49, $videoIds.Count - 1))])
  $data = Invoke-YouTubeGet -Endpoint "videos" -Params @{
    part       = "snippet,statistics,contentDetails"
    id         = ($batch -join ",")
    maxResults = 50
  }
  foreach ($item in @($data.items)) { $videos.Add($item) }
}

$allComments = New-Object System.Collections.Generic.List[object]
$errors = @{}

foreach ($videoId in $videoIds) {
  try {
    $threads = Get-YouTubePaged -Endpoint "commentThreads" -Params @{
      part       = "snippet,replies"
      videoId    = $videoId
      maxResults = [Math]::Min($maxComments, 100)
      order      = "time"
      textFormat = "plainText"
    } -MaxItems $maxComments

    foreach ($thread in @($threads)) {
      $top = $thread.snippet.topLevelComment
      $snippet = $top.snippet
      $allComments.Add([pscustomobject]@{
        video_id     = $videoId
        comment_id   = $top.id
        author       = $snippet.authorDisplayName
        published_at = $snippet.publishedAt
        like_count   = Get-NumberOrZero $snippet.likeCount
        text         = Clean-Text $snippet.textDisplay
        is_reply     = $false
      })

      foreach ($reply in @($thread.replies.comments)) {
        if (-not $reply) { continue }
        $replySnippet = $reply.snippet
        $allComments.Add([pscustomobject]@{
          video_id     = $videoId
          comment_id   = $reply.id
          author       = $replySnippet.authorDisplayName
          published_at = $replySnippet.publishedAt
          like_count   = Get-NumberOrZero $replySnippet.likeCount
          text         = Clean-Text $replySnippet.textDisplay
          is_reply     = $true
        })
      }
    }
  }
  catch {
    $errors[$videoId] = $_.Exception.Message
  }
}

$termsPath = Join-Path (Get-Location) "youtube_terms.json"
if (-not (Test-Path -LiteralPath $termsPath)) {
  $termsPath = Join-Path (Split-Path -Parent $PSScriptRoot) "references\youtube_terms.json"
}
if (-not (Test-Path -LiteralPath $termsPath)) {
  throw "Missing youtube_terms.json."
}
$terms = Get-Content -LiteralPath $termsPath -Encoding UTF8 -Raw | ConvertFrom-Json
$positiveWords = [string[]]@($terms.positiveWords | ForEach-Object { [string]$_ })
$painWords = [string[]]@($terms.painWords | ForEach-Object { [string]$_ })
$questionHints = [string[]]@($terms.questionHints | ForEach-Object { [string]$_ })
$themes = [ordered]@{}
foreach ($property in $terms.themes.PSObject.Properties) {
  $themes[$property.Name] = [string[]]@($property.Value | ForEach-Object { [string]$_ })
}

$themeCounts = @{}
foreach ($theme in $themes.Keys) { $themeCounts[$theme] = 0 }
$questions = New-Object System.Collections.Generic.List[object]
$positive = New-Object System.Collections.Generic.List[object]
$pain = New-Object System.Collections.Generic.List[object]
$keywordCounts = @{}

$allCommentItems = @($allComments.ToArray())
foreach ($comment in $allCommentItems) {
  $text = [string]$comment.text
  if (Contains-Any -Text $text -Words $questionHints) { $questions.Add($comment) }
  if (Contains-Any -Text $text -Words $positiveWords) { $positive.Add($comment) }
  if (Contains-Any -Text $text -Words $painWords) { $pain.Add($comment) }
  foreach ($theme in $themes.Keys) {
    if (Contains-Any -Text $text -Words $themes[$theme]) { $themeCounts[$theme]++ }
  }
  foreach ($match in [regex]::Matches($text, '[\u4e00-\u9fff]{2,}|[A-Za-z][A-Za-z'']{2,}')) {
    $word = $match.Value.ToLowerInvariant()
    if (@("the", "and", "you", "for", "with", "that", "this", "are", "was", "have", "but").Contains($word)) { continue }
    if (-not $keywordCounts.ContainsKey($word)) { $keywordCounts[$word] = 0 }
    $keywordCounts[$word]++
  }
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$videoRows = @($videos | ForEach-Object { Get-VideoRow -Video $_ -SubscriberCount $channelSubscribers })
$commentsPath = Join-Path $OutputDir "comments_$stamp.csv"
$videosPath = Join-Path $OutputDir "videos_$stamp.csv"
$rawPath = Join-Path $OutputDir "raw_$stamp.json"
$reportPath = Join-Path $OutputDir "report_$stamp.md"

$videoRows | Export-Csv -LiteralPath $videosPath -NoTypeInformation -Encoding UTF8
$allCommentItems | Export-Csv -LiteralPath $commentsPath -NoTypeInformation -Encoding UTF8
[pscustomobject]@{
  channel  = $channel
  videos   = $videos
  comments = $allCommentItems
  errors   = $errors
} | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $rawPath -Encoding UTF8

$videoById = @{}
foreach ($row in $videoRows) { $videoById[$row.video_id] = $row }
$commentsByVideo = @{}
foreach ($comment in $allCommentItems) {
  if (-not $commentsByVideo.ContainsKey($comment.video_id)) {
    $commentsByVideo[$comment.video_id] = New-Object System.Collections.Generic.List[object]
  }
  $commentsByVideo[$comment.video_id].Add($comment)
}

$totalViews = @($videoRows | Measure-Object -Property views -Sum).Sum
$totalLikes = @($videoRows | Measure-Object -Property likes -Sum).Sum
$totalPublicComments = @($videoRows | Measure-Object -Property comments -Sum).Sum

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# YouTube Recent Videos and Comment Analysis")
$lines.Add("")
$lines.Add("- Channel: $($channel.snippet.title)")
$lines.Add("- Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
$lines.Add("- Videos analyzed: $($videoRows.Count)")
$lines.Add("- Channel subscribers: $('{0:N0}' -f $channelSubscribers)")
$lines.Add("- Comments fetched: $($allCommentItems.Count)")
$lines.Add("- Public views total: $('{0:N0}' -f $totalViews)")
$lines.Add("- Public likes total: $('{0:N0}' -f $totalLikes)")
$lines.Add("- Public comments total: $('{0:N0}' -f $totalPublicComments)")
$lines.Add("")
$lines.Add("## Recent Video Performance")
$lines.Add("")
$lines.Add("| Published | Video | Views | Likes | Comments |")
$lines.Add("| --- | --- | ---: | ---: | ---: |")
foreach ($row in $videoRows) {
  $date = ([string]$row.published_at).Substring(0, 10)
  $title = $row.title.Replace("|", "\|")
  $lines.Add("| $date | [$title]($($row.url)) | $('{0:N0}' -f $row.views) | $('{0:N0}' -f $row.likes) | $('{0:N0}' -f $row.comments) |")
}
$lines.Add("")
$lines.Add("## Comment Themes")
$lines.Add("")
foreach ($item in ($themeCounts.GetEnumerator() | Sort-Object Value -Descending)) {
  if ($item.Value -gt 0) { $lines.Add("- $($item.Key): $($item.Value)") }
}
if (($themeCounts.Values | Measure-Object -Sum).Sum -eq 0) { $lines.Add("- No strong theme signal found with the current keyword set.") }
$lines.Add("")
$lines.Add("## Common Words")
$lines.Add("")
$commonWords = @($keywordCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 25 | ForEach-Object { "$($_.Key)($($_.Value))" })
$lines.Add(($commonWords -join ", "))
$lines.Add("")
$lines.Add("## Questions To Prioritize")
$lines.Add("")
$topQuestions = Get-TopComments -Comments $questions -Limit 10
foreach ($comment in $topQuestions) {
  $title = $videoById[$comment.video_id].title
  $lines.Add("- ${title}: $($comment.text)")
}
if ($topQuestions.Count -eq 0) { $lines.Add("- No clear question-style comments found.") }
$lines.Add("")
$lines.Add("## What Viewers Appreciate")
$lines.Add("")
$topPositive = Get-TopComments -Comments $positive -Limit 8
foreach ($comment in $topPositive) { $lines.Add("- $($comment.text)") }
if ($topPositive.Count -eq 0) { $lines.Add("- No clear positive keyword signal found.") }
$lines.Add("")
$lines.Add("## Viewer Anxiety and Friction")
$lines.Add("")
$topPain = Get-TopComments -Comments $pain -Limit 8
foreach ($comment in $topPain) { $lines.Add("- $($comment.text)") }
if ($topPain.Count -eq 0) { $lines.Add("- No clear anxiety/friction keyword signal found.") }
$lines.Add("")
$lines.Add("## Per-Video Comment Summary")
$lines.Add("")
foreach ($row in $videoRows) {
  if ($commentsByVideo.ContainsKey($row.video_id)) {
    $videoComments = @($commentsByVideo[$row.video_id].ToArray())
  }
  else {
    $videoComments = @()
  }
  $lines.Add("### $($row.title)")
  $lines.Add("")
  $lines.Add("- Link: $($row.url)")
  $lines.Add("- Comments fetched: $($videoComments.Count)")
  foreach ($comment in (Get-TopComments -Comments $videoComments -Limit 3)) {
    $lines.Add("- Selected comment: $($comment.text)")
  }
  if ($videoComments.Count -eq 0) { $lines.Add("- No comments fetched, or comments are disabled/restricted.") }
  $lines.Add("")
}

if ($errors.Count -gt 0) {
  $lines.Add("## Fetch Notes")
  $lines.Add("")
  foreach ($videoId in $errors.Keys) {
    $title = if ($videoById.ContainsKey($videoId)) { $videoById[$videoId].title } else { $videoId }
    $lines.Add("- ${title}: $($errors[$videoId])")
  }
  $lines.Add("")
}

$lines | Set-Content -LiteralPath $reportPath -Encoding UTF8
Write-Host "Done. Report: $reportPath"
