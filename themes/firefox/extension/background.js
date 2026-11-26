// Receives the theme from the native host (~/.config/themes/firefox/theme-sync-host), which
// sends it at startup and again every time `theme set` rewrites current/palette.json.
let retry = 1000;

function connect() {
  const port = browser.runtime.connectNative("theme_sync");
  port.onMessage.addListener((theme) => {
    retry = 1000;
    browser.theme.update(theme);
  });
  port.onDisconnect.addListener(() => {
    // Host missing or crashed: try again later, backing off up to a minute.
    setTimeout(connect, retry);
    retry = Math.min(retry * 2, 60000);
  });
}

connect();
