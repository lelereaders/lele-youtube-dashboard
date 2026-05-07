param(
  [string]$EnvPath = ".env",
  [string]$OutputPath = "data/kit-dashboard-data.js"
)

$ErrorActionPreference = "Stop"
$KitApiBase = "https://api.kit.com/v4"

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

function Invoke-KitGet {
  param(
    [string]$Path,
    [hashtable]$Params = @{}
  )

  $apiKey = [Environment]::GetEnvironmentVariable("KIT_API_KEY", "Process")
  if (-not $apiKey) {
    throw "Missing KIT_API_KEY. Add it to .env or GitHub Actions secrets."
  }

  $pairs = foreach ($key in $Params.Keys) {
    "{0}={1}" -f [uri]::EscapeDataString($key), [uri]::EscapeDataString([string]$Params[$key])
  }
  $query = if ($pairs.Count -gt 0) { "?$($pairs -join "&")" } else { "" }
  $uri = "{0}/{1}{2}" -f $KitApiBase, $Path.TrimStart("/"), $query

  $headers = @{
    "X-Kit-Api-Key" = $apiKey
  }

  try {
    Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
  }
  catch {
    $statusCode = $null
    if ($_.Exception.Response) {
      $statusCode = [int]$_.Exception.Response.StatusCode
    }
    $message = $_.Exception.Message
    throw "Kit API request failed ($statusCode) at $Path. $message"
  }
}

function Get-KitPaged {
  param(
    [string]$Path,
    [string]$CollectionName,
    [int]$MaxItems = 100,
    [bool]$IncludeTotalCount = $false
  )

  $items = New-Object System.Collections.Generic.List[object]
  $after = $null
  $totalCount = $null

  while ($true) {
    $params = @{
      per_page = [Math]::Min($MaxItems, 1000)
    }
    if ($after) { $params["after"] = $after }
    if ($IncludeTotalCount) { $params["include_total_count"] = "true" }

    $data = Invoke-KitGet -Path $Path -Params $params
    if ($null -eq $totalCount -and $data.pagination -and $null -ne $data.pagination.total_count) {
      $totalCount = Get-NumberOrZero $data.pagination.total_count
    }

    foreach ($item in @($data.$CollectionName)) {
      $items.Add($item)
      if ($MaxItems -gt 0 -and $items.Count -ge $MaxItems) {
        return [pscustomobject]@{ Items = @($items.ToArray()); TotalCount = $totalCount }
      }
    }

    if (-not $data.pagination -or -not $data.pagination.has_next_page) {
      return [pscustomobject]@{ Items = @($items.ToArray()); TotalCount = $totalCount }
    }
    $after = $data.pagination.end_cursor
  }
}

function Get-SubscriberCountFor {
  param(
    [string]$Path,
    [string]$CollectionName = "subscribers"
  )

  try {
    $data = Invoke-KitGet -Path $Path -Params @{
      per_page = 1
      include_total_count = "true"
    }
    if ($data.pagination -and $null -ne $data.pagination.total_count) {
      return Get-NumberOrZero $data.pagination.total_count
    }
    return @($data.$CollectionName).Count
  }
  catch {
    return 0
  }
}

function Format-Date {
  param($Value)
  if (-not $Value) { return "" }
  try {
    return ([datetime]$Value).ToString("yyyy-MM-dd")
  }
  catch {
    return [string]$Value
  }
}

Import-DotEnv -Path $EnvPath

$maxSubscribersValue = [Environment]::GetEnvironmentVariable("KIT_MAX_SUBSCRIBERS", "Process")
if (-not $maxSubscribersValue) { $maxSubscribersValue = "500" }
$maxAssetsValue = [Environment]::GetEnvironmentVariable("KIT_MAX_ASSETS", "Process")
if (-not $maxAssetsValue) { $maxAssetsValue = "100" }
$maxBroadcastsValue = [Environment]::GetEnvironmentVariable("KIT_MAX_BROADCASTS", "Process")
if (-not $maxBroadcastsValue) { $maxBroadcastsValue = "25" }

$maxSubscribers = [int]$maxSubscribersValue
$maxAssets = [int]$maxAssetsValue
$maxBroadcasts = [int]$maxBroadcastsValue

$subscribersResult = Get-KitPaged -Path "subscribers" -CollectionName "subscribers" -MaxItems $maxSubscribers -IncludeTotalCount $true
$formsResult = Get-KitPaged -Path "forms" -CollectionName "forms" -MaxItems $maxAssets
$tagsResult = Get-KitPaged -Path "tags" -CollectionName "tags" -MaxItems $maxAssets
$sequencesResult = Get-KitPaged -Path "sequences" -CollectionName "sequences" -MaxItems $maxAssets
$broadcastsResult = Get-KitPaged -Path "broadcasts" -CollectionName "broadcasts" -MaxItems $maxBroadcasts

$subscribers = @($subscribersResult.Items)
$forms = @($formsResult.Items | ForEach-Object {
  $count = Get-SubscriberCountFor -Path "forms/$($_.id)/subscribers"
  [pscustomobject][ordered]@{
    id = $_.id
    name = $_.name
    type = if ($_.type -eq "hosted") { "landing page" } else { $_.type }
    detail = "Created $(Format-Date $_.created_at)"
    url = $_.embed_url
    archived = [bool]$_.archived
    count = $count
  }
})

$tags = @($tagsResult.Items | ForEach-Object {
  $count = Get-SubscriberCountFor -Path "tags/$($_.id)/subscribers"
  [pscustomobject][ordered]@{
    id = $_.id
    name = $_.name
    detail = "Created $(Format-Date $_.created_at)"
    count = $count
  }
})

$sequences = @($sequencesResult.Items | ForEach-Object {
  $count = Get-SubscriberCountFor -Path "sequences/$($_.id)/subscribers"
  [pscustomobject][ordered]@{
    id = $_.id
    name = $_.name
    status = if ($_.active) { "active" } else { "inactive" }
    detail = "Send hour $($_.send_hour) · $($_.time_zone)"
    count = $count
  }
})

$broadcasts = @($broadcastsResult.Items | ForEach-Object {
  [pscustomobject][ordered]@{
    id = $_.id
    subject = if ($_.subject) { $_.subject } else { "(draft without subject)" }
    name = if ($_.subject) { $_.subject } else { "(draft without subject)" }
    status = if ($_.send_at) { "scheduled" } elseif ($_.published_at) { "published" } else { "draft" }
    detail = if ($_.send_at) { "Send at $(Format-Date $_.send_at)" } elseif ($_.published_at) { "Published $(Format-Date $_.published_at)" } else { "Created $(Format-Date $_.created_at)" }
    url = $_.public_url
  }
})

$subscriberRows = @($subscribers | Select-Object -First 100 | ForEach-Object {
  [pscustomobject][ordered]@{
    id = $_.id
    firstName = $_.first_name
    state = $_.state
    created = Format-Date $_.created_at
  }
})

$activeSubscribers = if ($subscribersResult.TotalCount) {
  $subscribersResult.TotalCount
} else {
  @($subscribers | Where-Object { $_.state -eq "active" }).Count
}

$payload = [pscustomobject][ordered]@{
  generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm")
  source = "Kit API v4"
  dashboard = [pscustomobject][ordered]@{
    metrics = [ordered]@{
      "Active subscribers" = Get-NumberOrZero $activeSubscribers
      "Subscribers fetched" = $subscribers.Count
      "Tags" = $tags.Count
      "Forms" = $forms.Count
      "Sequences" = $sequences.Count
      "Broadcasts" = $broadcasts.Count
    }
  }
  subscribers = $subscriberRows
  forms = $forms
  tags = $tags
  sequences = $sequences
  broadcasts = $broadcasts
  actionIdeas = @(
    [pscustomobject][ordered]@{ Type = "Tags 整理"; Recommendation = "優先合併意思重複的來源 tags，保留 source-youtube、source-instagram、freebie、customer、mastermind-interest 這類可行動標籤。"; Priority = "高" },
    [pscustomobject][ordered]@{ Type = "Landing form"; Recommendation = "把最高互動的內容 CTA 全部導向同一個 10 分鐘親子共讀開始包，先讓 Kit 資料乾淨。"; Priority = "高" },
    [pscustomobject][ordered]@{ Type = "Broadcast"; Recommendation = "LUNA 從 YouTube / Instagram 最高互動主題寫一封 broadcast，最後導到 freebie sequence 或 Mastermind 暖身。"; Priority = "中" }
  )
  automation = [pscustomobject][ordered]@{
    tags = @("source-youtube", "source-instagram", "interest-coreading", "interest-family-language", "freebie-10min-coreading", "customer-shopify", "mastermind-interest")
    segments = @("新加入 30 天內家長", "Instagram 高互動家長", "YouTube 留言互動家長", "共讀興趣家長", "家庭語言/廣東話/台語家庭", "已購買但未進 Mastermind")
    sequence = "Freebie nurture：第 1 封交付資源 -> 第 2 封共讀卡住安撫 -> 第 3 封家庭語言故事 -> 第 4 封 Mastermind / 閱讀挑戰邀請"
    landingForm = "孩子不愛說中文？領一份 10 分鐘親子共讀開始包"
    cta = "點這裡領取免費開始包，回信告訴我孩子年齡和家中最常用語言，我會幫你選一個不逼孩子的開始方式。"
    broadcast = "每週 1 封內容型 broadcast，加 1 封輕銷售 / 活動提醒；維持澳洲 sole trader 友善的簡單節奏。"
  }
  errors = [ordered]@{}
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
"window.LELE_KIT_DASHBOARD = $json;" | Set-Content -LiteralPath $resolvedOutputPath -Encoding UTF8
Write-Host "Wrote $resolvedOutputPath"
