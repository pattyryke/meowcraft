// Meowcraft website. Reads meowcraft.json, the latest release, Modrinth and the server status live.
(() => {
  const C = Object.assign({ repo: "pattyryke/meowcraft", server: "", map: "" }, window.MEOWCRAFT || {});
  const RAW = `https://raw.githubusercontent.com/${C.repo}/main`;
  const $ = (id) => document.getElementById(id);
  const el = (tag, props = {}, kids = []) => {
    const n = Object.assign(document.createElement(tag), props);
    kids.forEach((k) => n.append(k));
    return n;
  };
  const getJson = async (url) => {
    const r = await fetch(url, { cache: "no-store" });
    if (!r.ok) throw new Error(`${r.status} ${url}`);
    return r.json();
  };

  // ---------- Copy buttons ----------
  document.addEventListener("click", async (e) => {
    const b = e.target.closest("button.copy");
    if (!b) return;
    const text = $(b.dataset.copyFrom).textContent.trim();
    try { await navigator.clipboard.writeText(text); } catch {
      const r = document.createRange(); r.selectNodeContents($(b.dataset.copyFrom));
      const s = getSelection(); s.removeAllRanges(); s.addRange(r); document.execCommand("copy");
    }
    b.textContent = "Copied!"; b.classList.add("done");
    setTimeout(() => { b.textContent = "Copy"; b.classList.remove("done"); }, 1600);
  });

  // ---------- Setup tabs (picks your system) ----------
  const tabs = [...document.querySelectorAll("[data-tab]")];
  const showTab = (name) => {
    tabs.forEach((t) => t.setAttribute("aria-selected", String(t.dataset.tab === name)));
    document.querySelectorAll("[data-panel]").forEach((p) => { p.hidden = p.dataset.panel !== name; });
  };
  tabs.forEach((t) => t.addEventListener("click", () => showTab(t.dataset.tab)));
  const ua = navigator.userAgent;
  showTab(/Mac/.test(ua) && !/iPhone|iPad/.test(ua) ? "mac" : /Linux|CrOS/.test(ua) && !/Android/.test(ua) ? "other" : "windows");

  $("repo-link").href = `https://github.com/${C.repo}`;
  $("list-link").href = `https://github.com/${C.repo}/blob/main/meowcraft.json`;

  // ---------- Server address + online status ----------
  const statusChip = $("status-chip"), statusText = $("status-text");
  if (!C.server) {
    statusChip.classList.add("unknown");
    statusText.textContent = "Ask Patrick for the address";
  } else {
    $("address").textContent = C.server;
    $("address-box").hidden = false;
    const checkStatus = async () => {
      try {
        const s = await getJson(`https://api.mcsrvstat.us/3/${encodeURIComponent(C.server)}`);
        statusChip.classList.toggle("online", !!s.online);
        statusChip.classList.toggle("offline", !s.online);
        if (!s.online) { statusText.textContent = "Server is offline"; $("online-names").hidden = true; return; }
        const p = s.players || { online: 0, max: 0 };
        statusText.textContent = `Online · ${p.online}/${p.max} playing`;
        const names = (p.list || []).map((x) => x.name);
        $("online-names").hidden = !names.length;
        $("online-names").textContent = names.length ? `On now: ${names.join(", ")}` : "";
      } catch {
        statusChip.classList.add("unknown");
        statusText.textContent = "Couldn't check the server";
      }
    };
    checkStatus();
    setInterval(checkStatus, 60000);   // the status service caches for about a minute
  }

  // ---------- Pack downloads (latest release) ----------
  (async () => {
    const buttons = [...document.querySelectorAll("a.dl")];
    try {
      const rel = await getJson(`https://api.github.com/repos/${C.repo}/releases/latest`);
      buttons.forEach((b) => {
        const a = (rel.assets || []).find((x) => x.name === b.dataset.file);
        if (a) b.href = a.browser_download_url;
        else { b.classList.add("disabled"); b.removeAttribute("href"); }
      });
      $("pack-label").textContent = rel.name || rel.tag_name;
    } catch {
      buttons.forEach((b) => { b.classList.add("disabled"); b.removeAttribute("href"); b.textContent = "Pack file coming soon"; });
    }
  })();

  // ---------- Live map (squaremap, hosted on Cloudflare R2) ----------
  if (C.map) {
    $("map-wrap").append(el("iframe", { src: C.map, title: "Meowcraft live map", loading: "lazy", allow: "fullscreen" }));
    $("map-open").href = C.map;
    $("map").hidden = false;
    document.querySelectorAll("[data-map-link]").forEach((a) => { a.hidden = false; });
  }

  // ---------- What's inside (meowcraft.json + Modrinth) ----------
  const PERKS = {
    "simple-voice-chat": "Proximity voice chat",
    "xaeros-minimap": "Minimap and world map",
    "emotecraft": "Emotes",
    "sodium": "Big FPS boost",
    "jade": "See what you're looking at",
    "sound-physics-remastered": "Realistic echoes and sound",
    "zoomify": "Zoom",
    "iris": "Shaders",
    "fresh-animations": "Smoother mob animations",
    "entity-model-features": "Fancier mob models",
  };
  const card = (proj, slug, fancy) => {
    const kids = [];
    if (proj && proj.icon_url) kids.push(el("img", { src: proj.icon_url, alt: "", width: 40, height: 40, loading: "lazy" }));
    else kids.push(el("img", { src: "cat-256.png", alt: "", width: 40, height: 40 }));
    const text = el("div", {}, [el("b", { textContent: proj ? proj.title : slug })]);
    if (fancy) text.append(el("span", { className: "tag fancy-tag", textContent: "Fancy" }));
    if (proj && proj.description) text.append(el("p", { textContent: proj.description }));
    kids.push(text);
    return el("a", { className: "card", href: `https://modrinth.com/project/${proj ? proj.slug : slug}`, target: "_blank", rel: "noopener" }, kids);
  };

  (async () => {
    let m;
    try { m = await getJson(`${RAW}/meowcraft.json`); }
    catch { $("mods").replaceChildren(el("p", { className: "note", textContent: "Couldn't load the mod list right now." })); return; }

    $("version-chip").textContent = `Minecraft ${m.minecraft} · pack ${m.pack}`;
    const core = m.client.core, fancy = m.client.fancy || {};
    const coreMods = core.mods || [], fancyMods = (fancy.mods || []).filter((x) => !coreMods.includes(x));
    const packs = [...(core.resourcepacks || []), ...(fancy.resourcepacks || [])];
    const shaders = fancy.shaders || [];

    const perk = (ul, slugs) => slugs.forEach((s) => PERKS[s] && ul.append(el("li", { textContent: PERKS[s] })));
    perk($("perks-normal"), coreMods);
    perk($("perks-fancy"), [...fancyMods, ...(fancy.resourcepacks || [])]);
    shaders.forEach((s) => $("perks-fancy").append(el("li", { textContent: `${s.name} shaders` })));

    const ids = [...coreMods, ...fancyMods, ...packs, ...shaders.map((s) => s.project)];
    let byKey = {};
    try {
      const projs = await getJson(`https://api.modrinth.com/v2/projects?ids=${encodeURIComponent(JSON.stringify(ids))}`);
      projs.forEach((p) => { byKey[p.slug] = p; byKey[p.id] = p; });
    } catch { /* still show names without icons */ }

    $("mods").replaceChildren(
      ...coreMods.map((s) => card(byKey[s], s, false)),
      ...fancyMods.map((s) => card(byKey[s], s, true)),
      ...packs.map((s) => card(byKey[s], s, (fancy.resourcepacks || []).includes(s))),
    );
    $("shaders").replaceChildren(...shaders.map((s) => {
      const c = card(byKey[s.project], s.project, false);
      const tier = (s.file.match(/Meowcraft (\w+)/) || [])[1];
      if (tier) c.querySelector("div").prepend(el("span", { className: "tag", textContent: tier }));
      return c;
    }));
    $("plugins").replaceChildren(...(m.server.plugins || []).map((p) => el("li", { textContent: p.name })));
  })();
})();
