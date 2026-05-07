# Kit Dashboard Setup

這個 project 現在有 `kit.html`，會讀取 `data/kit-dashboard-data.js`。

## 需要準備

Kit API v4 使用 `X-Kit-Api-Key` 驗證。請先到 Kit 後台取得 API key，並確認你的 Kit 方案可以使用 API。

## GitHub Secret

到 GitHub repo：

`Settings` -> `Secrets and variables` -> `Actions` -> `New repository secret`

加入：

- `KIT_API_KEY`

可選：

- `KIT_MAX_SUBSCRIBERS`，預設 `500`
- `KIT_MAX_ASSETS`，預設 `100`
- `KIT_MAX_BROADCASTS`，預設 `25`

## 手動更新

在 GitHub 的 `Actions` 頁面，選：

`Update Kit Dashboard` -> `Run workflow`

成功後會更新：

- `data/kit-dashboard-data.js`
- `kit.html` 上看到最新 Kit dashboard

## 第一版會顯示

- subscribers 總數
- forms / landing pages
- tags
- sequences
- broadcasts / drafts / scheduled emails
- 建議的 tags、segments、sequence、landing form、CTA

## 建議先整理的 Kit 架構

- tags：`source-youtube`、`source-instagram`、`interest-coreading`、`interest-family-language`、`freebie-10min-coreading`、`customer-shopify`、`mastermind-interest`
- segments：新加入 30 天內家長、Instagram 高互動家長、YouTube 留言互動家長、共讀興趣家長、家庭語言/廣東話/台語家庭、已購買但未進 Mastermind
- sequence：Freebie nurture：第 1 封交付資源 -> 第 2 封共讀卡住安撫 -> 第 3 封家庭語言故事 -> 第 4 封 Mastermind / 閱讀挑戰邀請
- landing form：孩子不愛說中文？領一份 10 分鐘親子共讀開始包
- CTA：點這裡領取免費開始包，回信告訴我孩子年齡和家中最常用語言，我會幫你選一個不逼孩子的開始方式。
