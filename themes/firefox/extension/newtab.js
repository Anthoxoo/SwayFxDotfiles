// Blank new tab whose background follows the current theme live (Firefox's own blank page
// only reads its background color from a pref at startup).
function apply(theme) {
  const bg = theme && theme.colors && theme.colors.ntp_background;
  if (bg) document.documentElement.style.background = document.body.style.background = bg;
}
browser.theme.getCurrent().then(apply);
browser.theme.onUpdated.addListener(({ theme }) => apply(theme));
