var tabs = {};

chrome.tabs.onActivated.addListener(function(obj) {
  var id = obj.tabId;
  if (!tabs[id]) {
    tabs[id] = {
      showing: false
    };
  }
  chrome.browserAction.setIcon({ path: tabs[id].showing ? "active.png" : "inactive.png" });
});

chrome.browserAction.onClicked.addListener(function(tab) {
  if (tabs[tab.id].showing) {
    chrome.browserAction.setIcon({ path:"inactive.png" });
    chrome.tabs.executeScript(tab.id, { code: 'hide()' });
    tabs[tab.id].showing = false;
  }
  else {
    chrome.browserAction.setIcon({ path:"active.png" });
    chrome.tabs.executeScript(tab.id, { file: 'grep.js' });
    tabs[tab.id].showing = true;
  }
});
