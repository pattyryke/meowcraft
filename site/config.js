// The only file to edit for the website. Everything else (mods, pack number, downloads)
// comes from meowcraft.json and the Releases page by itself.
window.MEOWCRAFT = {
  // GitHub repo the site reads meowcraft.json and the pack downloads from.
  repo: "pattyryke/meowcraft",

  // Public address friends join with, e.g. "meowcraft.duckdns.org" (add ":port" if it isn't 25565).
  // Leave empty to show "ask Patrick for the address" and hide the online status.
  server: "meowcraft-server.duckdns.org",

  // The live map (squaremap), uploaded from the Pi to Cloudflare R2 by ~/docker/meowcraft/map-sync.
  // Leave empty to hide the map section.
  map: "https://pub-ee528d8f1d2348e9acaf0352f1584f29.r2.dev/index.html",
};
