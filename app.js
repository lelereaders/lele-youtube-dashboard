const data = window.LELE_YOUTUBE_DASHBOARD;

const numberFormat = new Intl.NumberFormat("zh-Hant");
const percentFormat = new Intl.NumberFormat("zh-Hant", {
  style: "percent",
  maximumFractionDigits: 1,
});

function value(name, fallback = 0) {
  return data.dashboard.metrics[name] ?? fallback;
}

function byNumber(field) {
  return (a, b) => Number(b[field] || 0) - Number(a[field] || 0);
}

function textIncludes(item, query) {
  return Object.values(item)
    .join(" ")
    .toLowerCase()
    .includes(query.toLowerCase());
}

function renderKpis() {
  document.querySelector("#sourceWorkbook").textContent = data.sourceWorkbook;
  document.querySelector("#generatedAt").textContent = `Generated ${data.generatedAt}`;
  document.querySelector("#kpiVideos").textContent = numberFormat.format(value("Videos analyzed"));
  document.querySelector("#kpiViews").textContent = numberFormat.format(value("Public views total"));
  document.querySelector("#kpiComments").textContent = numberFormat.format(value("Public comments total"));
  document.querySelector("#kpiFormats").textContent = `${value("Shorts count")} / ${value("Long-form count")}`;
}

function renderTopVideos() {
  const filter = document.querySelector("#formatFilter").value;
  const videos = data.videos
    .filter((video) => filter === "all" || video.Shorts === filter)
    .sort(byNumber("Views"))
    .slice(0, 10);

  const maxViews = Math.max(...videos.map((video) => Number(video.Views || 0)), 1);
  document.querySelector("#topVideosChart").innerHTML = videos
    .map((video) => {
      const width = Math.max(8, (Number(video.Views || 0) / maxViews) * 100);
      const engagement = Number(video["Engagement Rate"] || 0);
      return `
        <div class="bar-row">
          <div>
            <a class="video-title" href="${video.URL}" target="_blank" rel="noreferrer">${video.Title}</a>
            <div class="video-meta">${video.Published} · ${video.Shorts === "Yes" ? "Shorts" : "長影片"} · engagement ${percentFormat.format(engagement)}</div>
          </div>
          <div class="bar-track" aria-label="${video.Views} views">
            <div class="bar-fill" style="width:${width}%">${numberFormat.format(video.Views)}</div>
          </div>
        </div>
      `;
    })
    .join("");
}

function renderFormats() {
  const totalViews = data.dashboard.formats.reduce((sum, item) => sum + Number(item.views || 0), 0) || 1;
  document.querySelector("#formatChart").innerHTML = data.dashboard.formats
    .map((item) => {
      const width = (Number(item.views || 0) / totalViews) * 100;
      return `
        <div class="format-item">
          <strong>${item.format}</strong>
          <p>${numberFormat.format(item.count)} 支影片 · ${numberFormat.format(item.views)} views · 平均 ${numberFormat.format(item.avgViews)}</p>
          <div class="progress"><span style="width:${width}%"></span></div>
        </div>
      `;
    })
    .join("");
}

function renderThemes() {
  const countFor = (theme) => Number(theme.Count || theme["Comment Count"] || 0);
  const themes = data.themes.sort((a, b) => countFor(b) - countFor(a));
  const max = Math.max(...themes.map(countFor), 1);
  document.querySelector("#themeList").innerHTML = themes
    .map((theme) => {
      const count = countFor(theme);
      const width = (count / max) * 100;
      return `
        <div class="theme-item">
          <strong>${theme.Theme}</strong>
          <p>${numberFormat.format(count)} 則留言</p>
          <div class="progress"><span style="width:${width}%"></span></div>
        </div>
      `;
    })
    .join("");
}

function renderComments() {
  const query = document.querySelector("#commentSearch").value.trim();
  const comments = data.comments
    .filter((comment) => !query || textIncludes(comment, query))
    .slice(0, 30);

  document.querySelector("#commentsTable").innerHTML = comments
    .map((comment) => `
      <div class="comment-row">
        <div>
          <strong>${comment.Author}</strong>
          <small>${comment.Published}</small>
          <span class="pill">${comment.Category}</span>
        </div>
        <div>
          <a class="video-title" href="${comment["Video URL"]}" target="_blank" rel="noreferrer">${comment["Video Title"]}</a>
          <p>${comment.Comment}</p>
        </div>
        <div>
          <small>回覆方向</small>
          <p>${comment["Response Guidance"]}</p>
        </div>
      </div>
    `)
    .join("");
}

function renderIdeas() {
  document.querySelector("#actionIdeas").innerHTML = data.actionIdeas
    .map((idea) => {
      const title = idea.Type || idea["Content Idea"] || idea.Idea || idea.Topic || Object.values(idea)[0];
      const detail = idea.Recommendation || idea["Suggested CTA"] || idea["Notes"] || idea["Response Guidance"] || Object.values(idea).slice(1).join(" ");
      const reason = idea.Why ? `<p class="video-meta">${idea.Why}</p>` : "";
      const priority = idea.Priority ? `<span class="pill">${idea.Priority}</span>` : "";
      return `
        <div class="idea-card">
          <strong>${title}</strong>
          <p>${detail}</p>
          ${reason}
          ${priority}
        </div>
      `;
    })
    .join("");
}

function init() {
  renderKpis();
  renderTopVideos();
  renderFormats();
  renderThemes();
  renderComments();
  renderIdeas();

  document.querySelector("#formatFilter").addEventListener("change", renderTopVideos);
  document.querySelector("#commentSearch").addEventListener("input", renderComments);
}

init();
