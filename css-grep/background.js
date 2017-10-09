var showing = false;
chrome.browserAction.onClicked.addListener(function(tab) {
  if (showing) {
    chrome.browserAction.setIcon({ path:"inactive.png" });
    chrome.tabs.executeScript(tab.id, { code: 'hide()' });
    showing = false;
  }
  else {
    chrome.browserAction.setIcon({ path:"active.png" });
    chrome.tabs.executeScript(tab.id, { file: 'grep.js' });
    showing = true;
  }
});
