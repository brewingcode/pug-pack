var showing = false;
chrome.browserAction.onClicked.addListener(function(tab) {
  if (showing) {
    chrome.tabs.executeScript(tab.id, { code: 'hide()' });
    showing = false;
  }
  else {
    chrome.tabs.executeScript(tab.id, { file: 'grep.js' });
    showing = true;
  }
});
