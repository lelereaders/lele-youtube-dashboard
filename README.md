# Le Le Culture YouTube Dashboard

這是一個可直接上傳到 GitHub Pages 的 YouTube Dashboard。它可以用 GitHub Actions 每週自動抓 YouTube 最新影片與留言，更新網頁資料。

## 本機手動更新

在這個資料夾執行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\update-dashboard.ps1
```

這會重新抓 YouTube 資料、產生 `youtube_reports/YouTube_Comment_Insights_latest.xlsx`，再更新 `data/youtube-dashboard-data.js`。

本機需要先建立 `.env`，可參考 `.env.example`：

```text
YOUTUBE_API_KEY=你的 YouTube Data API key
YOUTUBE_CHANNEL_ID=@YourYouTubeHandle
YOUTUBE_MAX_VIDEOS=100
YOUTUBE_MAX_COMMENTS_PER_VIDEO=100
```

## GitHub Pages 發布

1. 建立一個 GitHub repo。
2. 上傳這個資料夾裡的所有檔案。
3. 到 GitHub repo 的 `Settings` → `Pages`。
4. Source 選 `Deploy from a branch`。
5. Branch 選 `main`，folder 選 `/root`。
6. 儲存後，GitHub 會提供一個公開網址。

## 全自動更新

這個 repo 已包含 `.github/workflows/update-youtube-dashboard.yml`。

排程：每週一 00:00 UTC 執行，也就是 Perth 時間每週一早上 8:00。

你需要在 GitHub repo 設定兩個 Secrets：

1. `YOUTUBE_API_KEY`
2. `YOUTUBE_CHANNEL_ID`

位置：`Settings` → `Secrets and variables` → `Actions` → `New repository secret`。

也可以到 GitHub repo 的 `Actions` 頁面，手動按 `Update YouTube Dashboard` → `Run workflow`，立即更新一次。

## 建議 Kit 銜接

- tags：`YT-comment-family-language`、`YT-comment-coreading`、`YT-comment-identity-risk`、`YT-clicked-freebie`
- segments：留言互動家長、共讀興趣家長、廣東話/台語家庭、需要低壓中文方法的海外家庭
- sequence：留言延伸故事 → 免費活動紙 → Mastermind / 閱讀挑戰邀請
- landing form：YouTube 專屬「10 分鐘親子共讀開始包」
- CTA：留言或填表分享「你家現在最常用哪一種家庭語言？」
