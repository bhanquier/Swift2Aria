document.addEventListener("DOMContentLoaded", async () => {
  const urlEl = document.getElementById("url");
  const btn = document.getElementById("send");
  const statusEl = document.getElementById("status");

  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  const currentUrl = tab?.url || "";

  if (!currentUrl || currentUrl.startsWith("chrome:")) {
    urlEl.textContent = "No valid URL on this tab";
    btn.disabled = true;
    return;
  }

  urlEl.textContent = currentUrl;

  btn.addEventListener("click", () => {
    const encoded = encodeURIComponent(currentUrl);
    chrome.tabs.create({ url: `swift2aria://add?url=${encoded}` });
    statusEl.textContent = "Sent to Swift2Aria!";
    setTimeout(() => { statusEl.textContent = ""; }, 2000);
  });
});
