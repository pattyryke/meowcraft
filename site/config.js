// The only file to edit for the website. Everything else (mods, pack number, downloads)
// comes from meowcraft.json and the Releases page by itself.
window.MEOWCRAFT = {
  // GitHub repo the site reads meowcraft.json and the pack downloads from.
  repo: "pattyryke/meowcraft",

  // Public address friends join with, e.g. "meowcraft.duckdns.org" (add ":port" if it isn't 25565).
  // Leave empty to show "ask Patrick for the address" and hide the online status.
  server: "",

  // BlueMap over https (the Caddy setup), e.g. "https://meowcraft.duckdns.org".
  // Leave empty to show "map coming soon".
  map: "",

  // Which BlueMap map the live player list reads (BlueMap's default overworld is "world").
  mapId: "world",
};
