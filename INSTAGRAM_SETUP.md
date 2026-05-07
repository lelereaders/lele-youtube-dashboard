# Instagram Dashboard Setup

這個 project 現在有第二個頁面：`instagram.html`。它和 YouTube dashboard 一樣，可以放在 GitHub Pages 上，用 GitHub Actions 每週自動更新。

## 需要先準備

Instagram 的資料不是 GitHub 自己能讀到的，需要 Meta / Instagram Graph API 權限：

1. Instagram 帳號要是 Business 或 Creator account。
2. Instagram 帳號需要連到 Facebook Page。
3. Meta app 需要可讀取 Instagram profile、media、insights，以及留言的權限。
4. 建議使用 long-lived access token，避免每次手動更新。

## GitHub Secrets

到 GitHub repo：

`Settings` -> `Secrets and variables` -> `Actions` -> `New repository secret`

加入：

- `INSTAGRAM_USER_ID`
- `INSTAGRAM_ACCESS_TOKEN`

可選：

- `INSTAGRAM_GRAPH_VERSION`，預設 `v25.0`
- `INSTAGRAM_MAX_MEDIA`，預設 `50`
- `INSTAGRAM_MAX_COMMENTS_PER_MEDIA`，預設 `25`

## 手動更新

在 GitHub 的 `Actions` 頁面，選：

`Update Instagram Dashboard` -> `Run workflow`

成功後會更新：

- `data/instagram-dashboard-data.js`
- `instagram.html` 上看到最新 Instagram dashboard

## Kit 銜接建議

- tags：`IG-engaged-parent`、`IG-reels-coreading`、`IG-comment-family-language`、`IG-clicked-freebie`
- segments：Instagram 高互動家長、共讀興趣家長、家庭語言/廣東話/台語家庭、需要低壓中文方法的海外家庭
- sequence：留言互動故事 -> 10 分鐘共讀開始包 -> Mastermind / 閱讀挑戰邀請
- landing form：Instagram 專屬「孩子不愛說中文？領一份 10 分鐘親子共讀開始包」
- CTA：留言「共讀」告訴我孩子年齡和家中最常用語言，我把適合你家的開始方式整理給你。
