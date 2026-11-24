// Points the download button straight at the newest release's ISO, with its version, size and date.
// If GitHub can't be reached, the button keeps its fallback link to the latest release page.
(async () => {
  const label = document.getElementById("download-label");
  const meta = document.getElementById("download-meta");
  const button = document.getElementById("download");
  const checksum = document.getElementById("checksum");
  try {
    const res = await fetch("https://api.github.com/repos/goseahawk/kirkus/releases/latest",
                            { headers: { Accept: "application/vnd.github+json" } });
    if (!res.ok) return;
    const release = await res.json();
    const assets = release.assets || [];
    const iso = assets.find((a) => a.name.endsWith(".iso"));
    const sum = assets.find((a) => a.name.endsWith(".iso.sha256"));
    if (!iso) return;
    const version = release.tag_name;
    const size = (iso.size / 1024 ** 3).toFixed(1).replace(/\.0$/, "");
    const date = new Date(release.published_at).toLocaleDateString(undefined,
                   { day: "numeric", month: "long", year: "numeric" });
    button.href = iso.browser_download_url;
    label.textContent = `Download kirkus ${version}`;
    meta.textContent = `${size} GB · released ${date} · for PCs and Intel Macs`;
    if (sum) checksum.href = sum.browser_download_url;
  } catch (e) {
    // offline or rate-limited: the fallback link still works
  }
})();
