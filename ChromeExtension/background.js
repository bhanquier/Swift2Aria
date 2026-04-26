chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: "download-link",
    title: "Download with Swift2Aria",
    contexts: ["link"]
  });

  chrome.contextMenus.create({
    id: "download-page",
    title: "Send page to Swift2Aria",
    contexts: ["page"]
  });
});

chrome.contextMenus.onClicked.addListener((info, tab) => {
  let url = "";
  if (info.menuItemId === "download-link" && info.linkUrl) {
    url = info.linkUrl;
  } else if (info.menuItemId === "download-page" && tab?.url) {
    url = tab.url;
  }
  if (url) {
    openSwift2Aria(url);
  }
});

function openSwift2Aria(url) {
  const encoded = encodeURIComponent(url);
  chrome.tabs.create({ url: `swift2aria://add?url=${encoded}` });
}
