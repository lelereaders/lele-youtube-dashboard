window.LELE_KIT_DASHBOARD = {
  "generatedAt": "Not connected yet",
  "source": "Kit API v4",
  "dashboard": {
    "metrics": {
      "Active subscribers": 0,
      "Subscribers fetched": 0,
      "Tags": 0,
      "Forms": 0,
      "Sequences": 0,
      "Broadcasts": 0
    }
  },
  "subscribers": [],
  "forms": [],
  "tags": [],
  "sequences": [],
  "broadcasts": [],
  "actionIdeas": [
    {
      "Type": "先接 Kit API",
      "Recommendation": "在 GitHub Secrets 加入 KIT_API_KEY 後，執行 Update Kit Dashboard。第一版會先看 subscribers、forms、tags、sequences、broadcasts。",
      "Priority": "高"
    },
    {
      "Type": "整理 tags",
      "Recommendation": "先統一來源與興趣 tags：YT、IG、freebie、coreading、family-language、purchased，避免一個家長被貼太多意思重複的標籤。",
      "Priority": "高"
    },
    {
      "Type": "下一封 broadcast",
      "Recommendation": "LUNA 從最高互動的 YouTube / Instagram 主題寫一封電子報，CTA 指向 10 分鐘親子共讀開始包。",
      "Priority": "中"
    }
  ],
  "automation": {
    "tags": [
      "source-youtube",
      "source-instagram",
      "interest-coreading",
      "interest-family-language",
      "freebie-10min-coreading",
      "customer-shopify",
      "mastermind-interest"
    ],
    "segments": [
      "新加入 30 天內家長",
      "Instagram 高互動家長",
      "YouTube 留言互動家長",
      "共讀興趣家長",
      "家庭語言/廣東話/台語家庭",
      "已購買但未進 Mastermind"
    ],
    "sequence": "Freebie nurture：第 1 封交付資源 -> 第 2 封共讀卡住安撫 -> 第 3 封家庭語言故事 -> 第 4 封 Mastermind / 閱讀挑戰邀請",
    "landingForm": "孩子不愛說中文？領一份 10 分鐘親子共讀開始包",
    "cta": "點這裡領取免費開始包，回信告訴我孩子年齡和家中最常用語言，我會幫你選一個不逼孩子的開始方式。",
    "broadcast": "每週 1 封內容型 broadcast，加 1 封輕銷售 / 活動提醒；維持澳洲 sole trader 友善的簡單節奏。"
  },
  "errors": {}
};
