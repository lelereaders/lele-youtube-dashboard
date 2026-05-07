const instagramData = window.LELE_INSTAGRAM_DASHBOARD;

const numberFormat = new Intl.NumberFormat("zh-Hant");
const percentFormat = new Intl.NumberFormat("zh-Hant", {
  style: "percent",
  maximumFractionDigits: 1,
});

function metric(name, fallback = 0) {
  return instagramData.dashboard.metrics[name] ?? fallback;
}

function sortByNumber(field) {
  return (a, b) => Number(b[field] || 0) - Number(a[field] || 0);
}

function includesText(item, query) {
  return Object.values(item)
    .join(" ")
    .toLowerCase()
    .includes(query.toLowerCase());
}

function renderInstagramKpis() {
  document.querySelector("#igSource").textContent = instagramData.source;
  document.querySelector("#igGeneratedAt").textContent = `Updated ${instagramData.generatedAt}`;
  document.querySelector("#igAccount").textContent = instagramData.profile.username ? `@${instagramData.profile.username}` : "Instagram account";
  document.querySelector("#igPosts").textContent = numberFormat.format(metric("Posts analyzed"));
  document.querySelector("#igFollowers").textContent = numberFormat.format(metric("Followers"));
  document.querySelector("#igEngagement").textContent = numberFormat.format(metric("Interactions total"));
  document.querySelector("#igComments").textContent = numberFormat.format(metric("Comments total"));
}

function renderTopMedia() {
  const mode = document.querySelector("#igSortFilter").value;
  const field = mode === "comments" ? "Comments" : mode === "likes" ? "Likes" : "Interactions";
  const items = instagramData.media.sort(sortByNumber(field)).slice(0, 12);
  const maxValue = Math.max(...items.map((item) => Number(item[field] || 0)), 1);

  document.querySelector("#igTopMedia").innerHTML = items.length
    ? items.map((item) => {
        const width = Math.max(8, (Number(item[field] || 0) / maxValue) * 100);
        const caption = item.Caption || "(No caption)";
        const shortCaption = caption.length > 120 ? `${caption.slice(0, 120)}...` : caption;
        return `
          <div class="bar-row">
            <div>
              <a class="video-title" href="${item.URL}" target="_blank" rel="noreferrer">${shortCaption}</a>
              <div class="video-meta">${item.Published || ""} · ${item.Product || item.Type || "Post"} · ${item.Theme || "未分類"} · engagement ${percentFormat.format(Number(item["Engagement Rate"] || 0))}</div>
            </div>
            <div class="bar-track" aria-label="${field}">
              <div class="bar-fill" style="width:${width}%">${numberFormat.format(item[field] || 0)}</div>
            </div>
          </div>
        `;
      }).join("")
    : `<p class="empty-state">還沒有 Instagram 資料。接好 GitHub Secrets 後，執行一次 workflow 就會出現在這裡。</p>`;
}

function renderThemes() {
  const themes = instagramData.themes || [];
  const max = Math.max(...themes.map((theme) => Number(theme.Count || 0)), 1);
  document.querySelector("#igThemeList").innerHTML = themes.length
    ? themes.map((theme) => {
        const width = (Number(theme.Count || 0) / max) * 100;
        return `
          <div class="theme-item">
            <strong>${theme.Theme}</strong>
            <p>${numberFormat.format(theme.Count || 0)} 則訊號</p>
            <div class="progress"><span style="width:${width}%"></span></div>
          </div>
        `;
      }).join("")
    : `<p class="empty-state">連接後會依 caption 與留言自動標記主題。</p>`;
}

function renderComments() {
  const query = document.querySelector("#igCommentSearch").value.trim();
  const comments = (instagramData.comments || [])
    .filter((comment) => !query || includesText(comment, query))
    .slice(0, 30);

  document.querySelector("#igCommentsTable").innerHTML = comments.length
    ? comments.map((comment) => `
      <div class="comment-row">
        <div>
          <strong>${comment.Username || "Instagram user"}</strong>
          <small>${comment.Published || ""}</small>
          <span class="pill">${comment.Category || "未分類"}</span>
        </div>
        <div>
          <a class="video-title" href="${comment["Media URL"]}" target="_blank" rel="noreferrer">${comment.Media || "Instagram post"}</a>
          <p>${comment.Comment || ""}</p>
        </div>
        <div>
          <small>回覆方向</small>
          <p>${comment["Response Guidance"] || ""}</p>
        </div>
      </div>
    `).join("")
    : `<p class="empty-state">目前沒有可顯示的 Instagram 留言。若 API 權限未開留言讀取，貼文表現仍可更新。</p>`;
}

function renderIdeas() {
  document.querySelector("#igActionIdeas").innerHTML = (instagramData.actionIdeas || [])
    .map((idea) => `
      <div class="idea-card">
        <strong>${idea.Type}</strong>
        <p>${idea.Recommendation}</p>
        ${idea.Priority ? `<span class="pill">${idea.Priority}</span>` : ""}
      </div>
    `)
    .join("");
}

function renderAutomation() {
  const automation = instagramData.automation || {};
  document.querySelector("#igAutomation").innerHTML = `
    <div><strong>tags</strong><p>${(automation.tags || []).join("、")}</p></div>
    <div><strong>segments</strong><p>${(automation.segments || []).join("、")}</p></div>
    <div><strong>sequence</strong><p>${automation.sequence || ""}</p></div>
    <div><strong>landing form</strong><p>${automation.landingForm || ""}</p></div>
    <div><strong>CTA</strong><p>${automation.cta || ""}</p></div>
    <div><strong>LUNA / 芳芳</strong><p>LUNA 把高互動貼文延伸成電子報；芳芳把留言問題整理成 Le Le Talk 題目。</p></div>
  `;
}

function initInstagramDashboard() {
  renderInstagramKpis();
  renderTopMedia();
  renderThemes();
  renderComments();
  renderIdeas();
  renderAutomation();

  document.querySelector("#igSortFilter").addEventListener("change", renderTopMedia);
  document.querySelector("#igCommentSearch").addEventListener("input", renderComments);
}

initInstagramDashboard();
