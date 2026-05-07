const youtubeData = window.LELE_YOUTUBE_DASHBOARD || {};
const instagramData = window.LELE_INSTAGRAM_DASHBOARD || {};
const kitData = window.LELE_KIT_DASHBOARD || {};

const overviewNumberFormat = new Intl.NumberFormat("zh-Hant");

function getMetric(source, name) {
  return source?.dashboard?.metrics?.[name] ?? 0;
}

function renderIdea(target, idea) {
  document.querySelector(target).innerHTML = `
    <div class="idea-card">
      <strong>${idea?.Type || "下一步"}</strong>
      <p>${idea?.Recommendation || "資料連接後，這裡會顯示下一步內容建議。"}</p>
      ${idea?.Priority ? `<span class="pill">${idea.Priority}</span>` : ""}
    </div>
  `;
}

function initOverview() {
  const generated = [youtubeData.generatedAt, instagramData.generatedAt, kitData.generatedAt]
    .filter(Boolean)
    .join(" / ");
  document.querySelector("#overviewGeneratedAt").textContent = generated ? `Updated ${generated}` : "";

  document.querySelector("#overviewYoutubeViews").textContent = overviewNumberFormat.format(getMetric(youtubeData, "Public views total"));
  document.querySelector("#overviewInstagramInteractions").textContent = overviewNumberFormat.format(getMetric(instagramData, "Interactions total"));
  document.querySelector("#overviewSubscribers").textContent = overviewNumberFormat.format(getMetric(kitData, "Active subscribers"));
  document.querySelector("#overviewForms").textContent = overviewNumberFormat.format(getMetric(kitData, "Forms"));

  renderIdea("#overviewYoutubeIdea", youtubeData.actionIdeas?.[0]);
  renderIdea("#overviewInstagramIdea", instagramData.actionIdeas?.[0]);

  const automation = kitData.automation || {};
  document.querySelector("#overviewKitPlan").innerHTML = `
    <div><strong>tags</strong><p>${(automation.tags || []).join("、") || "先整理來源與興趣 tags。"}</p></div>
    <div><strong>segments</strong><p>${(automation.segments || []).join("、") || "先分出 YouTube / Instagram / 已購買 / 高互動家長。"}</p></div>
    <div><strong>sequence</strong><p>${automation.sequence || "先建立 freebie nurture sequence。"}</p></div>
    <div><strong>landing form</strong><p>${automation.landingForm || "用一個清楚的 10 分鐘親子共讀開始包承接新名單。"}</p></div>
    <div><strong>CTA</strong><p>${automation.cta || "留言或點擊領取資源，讓家長進入 Kit automation。"}</p></div>
    <div><strong>broadcast</strong><p>${automation.broadcast || "LUNA 每週從最高互動內容產出一封溫柔銷售信。"}</p></div>
  `;
}

initOverview();
