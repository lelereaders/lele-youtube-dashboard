const kitData = window.LELE_KIT_DASHBOARD;

const kitNumberFormat = new Intl.NumberFormat("zh-Hant");

function kitMetric(name, fallback = 0) {
  return kitData.dashboard.metrics[name] ?? fallback;
}

function kitSortByCount(items) {
  return [...(items || [])].sort((a, b) => Number(b.count || 0) - Number(a.count || 0));
}

function renderKitKpis() {
  document.querySelector("#kitSource").textContent = kitData.source;
  document.querySelector("#kitGeneratedAt").textContent = `Updated ${kitData.generatedAt}`;
  document.querySelector("#kitSubscribers").textContent = kitNumberFormat.format(kitMetric("Active subscribers"));
  document.querySelector("#kitTags").textContent = kitNumberFormat.format(kitMetric("Tags"));
  document.querySelector("#kitForms").textContent = kitNumberFormat.format(kitMetric("Forms"));
  document.querySelector("#kitSequences").textContent = kitNumberFormat.format(kitMetric("Sequences"));
}

function renderList(target, items, emptyText) {
  document.querySelector(target).innerHTML = items.length
    ? items.map((item) => `
      <div class="theme-item">
        <strong>${item.name || item.subject || "Untitled"}</strong>
        <p>${item.detail || item.type || item.status || ""}</p>
        ${Number.isFinite(Number(item.count)) ? `<span class="pill">${kitNumberFormat.format(item.count)} subscribers</span>` : ""}
      </div>
    `).join("")
    : `<p class="empty-state">${emptyText}</p>`;
}

function renderKitAssets() {
  renderList("#kitFormsList", kitSortByCount(kitData.forms), "連接 Kit 後，這裡會列出 landing forms 與各自 subscriber 數。");
  renderList("#kitTagsList", kitSortByCount(kitData.tags), "連接 Kit 後，這裡會列出 tags，方便整理是否重複。");
  renderList("#kitSequencesList", kitSortByCount(kitData.sequences), "連接 Kit 後，這裡會列出 sequences 與每個 sequence 裡的 subscriber 數。");
  renderList("#kitBroadcastsList", kitData.broadcasts || [], "連接 Kit 後，這裡會列出最近 broadcasts / drafts / scheduled emails。");
}

function renderKitIdeas() {
  document.querySelector("#kitActionIdeas").innerHTML = (kitData.actionIdeas || [])
    .map((idea) => `
      <div class="idea-card">
        <strong>${idea.Type}</strong>
        <p>${idea.Recommendation}</p>
        ${idea.Priority ? `<span class="pill">${idea.Priority}</span>` : ""}
      </div>
    `)
    .join("");
}

function renderKitAutomation() {
  const automation = kitData.automation || {};
  document.querySelector("#kitAutomation").innerHTML = `
    <div><strong>tags</strong><p>${(automation.tags || []).join("、")}</p></div>
    <div><strong>segments</strong><p>${(automation.segments || []).join("、")}</p></div>
    <div><strong>sequence</strong><p>${automation.sequence || ""}</p></div>
    <div><strong>landing form</strong><p>${automation.landingForm || ""}</p></div>
    <div><strong>CTA</strong><p>${automation.cta || ""}</p></div>
    <div><strong>broadcast</strong><p>${automation.broadcast || ""}</p></div>
  `;
}

function initKitDashboard() {
  renderKitKpis();
  renderKitAssets();
  renderKitIdeas();
  renderKitAutomation();
}

initKitDashboard();
