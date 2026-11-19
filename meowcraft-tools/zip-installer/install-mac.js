// Meowcraft client installer (Mac): adds a "Meowcraft" profile (Fabric + mods) to the official Minecraft Launcher.
ObjC.import('Foundation');

// ---- Built-in lists (used only if the online list in manifest-url.txt can't be read) ----
let MC_VERSION = '26.3';
const CORE_MODS = ['fabric-api', 'sodium', 'immediatelyfast', 'modmenu', 'xaeros-minimap', 'xaeros-world-map', 'jade', 'appleskin', 'mouse-tweaks', 'zoomify', 'simple-voice-chat', 'emotecraft', 'clientsort'];
const FANCY_MODS = ['iris', 'entity-model-features', 'entitytexturefeatures'];
const FANCY_PACKS = ['fresh-animations'];
const FANCY_SHADERS = [['HVnmMxH1', 'Meowcraft High - Complementary Reimagined.zip'], ['Q1vvjJYV', 'Meowcraft Medium - BSL.zip'], ['makeup-ultra-fast-shaders', 'Meowcraft Low - MakeUp Ultra Fast.zip']];
const FANCY_DEFAULT_SHADER = 'Meowcraft Low - MakeUp Ultra Fast.zip';
// -------------------------------------------------------------------------------------------
let MODS = [], PACKS = [], SHADERS = [], DEFAULT_SHADER = '';
const KNOWN_PACKS = ['fresh-animations'];

const UA = 'pattycakez69/meowcraft-installer/1.3';
const ICON = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAABeElEQVR4Xu2aIW/CUBSFW8I0CRL01NwsAmpn+AMY5IIhm52cHeEnIPgDNbNgsPwBNJYEPbNg3rtNerP7wsrhJudTJWnKvZxzXm95zWfDVeaZlufiL7ABNG1ZwPbwVlvP6HEBqdNSDy2Exr0ClQxIdvNu+DhYxmw0nQfp+2oNp1qx3SvABtCoGeg8fIXadvP3RvOg+V7WkGVTZuAucR9iNQMa2v3hGuQ1U3GvABtAo2bg/BPXfguWucVyjsRSAy2Exr0C+VMvzv3XrMe3ZCCeDdwrwAbQmGahyXgU6twX3+H4efMSjtflNqmX/7omLYSGCqChAmjcK9DILFT9Pydime8tcBa6J9xnwDQLdcafST96v3itPf+4SdtrO5cff36vewXYABpTBiz0i7iPpnndck4qtBAa9wrk8n0hba9KknpPSEVb++X8I/eq3SvABtBUMiCx5KFpNN9LaCE07hVQM6Dl4ZZY3k1yrwAbQGN6HrB4EQUthMa9Ar+V1GApTOWmuAAAAABJRU5ErkJggg==';
const app = Application.currentApplication();
app.includeStandardAdditions = true;
const fm = $.NSFileManager.defaultManager;

function sh(cmd) { return app.doShellScript(cmd, { alteringLineEndings: false }); }
function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }
function exists(p) { return fm.fileExistsAtPath(p); }
function readText(p) { return sh('cat ' + q(p)); }
function writeText(p, text) {
  $.NSString.alloc.initWithUTF8String(text).writeToFileAtomicallyEncodingError(p, true, $.NSUTF8StringEncoding, null);
}
function getJson(url) { return JSON.parse(sh('curl -fsSL -A ' + q(UA) + ' ' + q(url))); }
function download(url, dest) { sh('curl -fsSL -A ' + q(UA) + ' -o ' + q(dest) + ' ' + q(url)); }
function say(msg) { console.log('  =^.^=  ' + msg); }
function warn(msg) { console.log('  !!  ' + msg); }
function getVersions(project, loader) {
  const qs = 'loaders=' + encodeURIComponent(JSON.stringify([loader])) + '&game_versions=' + encodeURIComponent(JSON.stringify([MC_VERSION]));
  try { return getJson('https://api.modrinth.com/v2/project/' + encodeURIComponent(project) + '/version?' + qs); } catch (e) { return []; }
}
function primaryFile(v) { return v.files.find(f => f.primary) || v.files[0]; }

function run(argv) {
  const here = argv[0];
  const home = sh('echo $HOME').trim();
  const mcDir = home + '/Library/Application Support/minecraft';
  const gameDir = mcDir + '/meowcraft';
  const modsDir = gameDir + '/mods';
  const packDir = gameDir + '/resourcepacks';
  const optFile = gameDir + '/options.txt';
  const ownedPath = modsDir + '/.meowcraft-owned';
  const lpPath = mcDir + '/launcher_profiles.json';

  function setPackEnabled(fileName, enabled) {
    const entry = 'file/' + fileName;
    let lines = exists(optFile) ? readText(optFile).split('\n') : [];
    if (lines.length && lines[lines.length - 1] === '') lines.pop();
    let idx = lines.findIndex(l => l.startsWith('resourcePacks:'));
    let list = idx >= 0 ? JSON.parse(lines[idx].slice(14)) : ['vanilla'];
    list = list.filter(x => x !== entry);
    if (enabled) list.push(entry);
    const line = 'resourcePacks:' + JSON.stringify(list);
    if (idx >= 0) lines[idx] = line; else lines.push(line);
    writeText(optFile, lines.join('\n') + '\n');
  }

  // Which set to install: variant.txt says core or fancy
  const variant = exists(here + '/variant.txt') ? readText(here + '/variant.txt').trim().toLowerCase() : 'core';
  MODS = CORE_MODS.slice();
  if (variant === 'fancy') { MODS = MODS.concat(FANCY_MODS); PACKS = FANCY_PACKS.slice(); SHADERS = FANCY_SHADERS.slice(); DEFAULT_SHADER = FANCY_DEFAULT_SHADER; }
  console.log('\n  Meowcraft installer (' + variant + ')\n');

  // Use the online master list (meowcraft.json on GitHub) if one is set up
  const murl = exists(here + '/manifest-url.txt') ? readText(here + '/manifest-url.txt').trim() : '';
  if (murl && murl.indexOf('YOUR-GITHUB-NAME') < 0) {
    try {
      const man = getJson(murl);
      const chain = [];
      for (let cur = variant; cur; cur = (man.client[cur] || {}).extends) chain.unshift(cur);
      MODS = []; PACKS = []; SHADERS = []; DEFAULT_SHADER = '';
      chain.forEach(c => {
        const sec = man.client[c] || {};
        (sec.mods || []).forEach(m => { if (MODS.indexOf(m) < 0) MODS.push(m); });
        (sec.resourcepacks || []).forEach(p => { if (PACKS.indexOf(p) < 0) PACKS.push(p); });
        (sec.shaders || []).forEach(s => SHADERS.push([s.project, s.file]));
        if (sec.default_shader) DEFAULT_SHADER = sec.default_shader;
      });
      if (man.minecraft) MC_VERSION = man.minecraft;
      say('Using the Meowcraft mod list from GitHub (Minecraft ' + MC_VERSION + ')');
    } catch (e) { warn("Couldn't read the online mod list - using the built-in one"); }
  }
  if (!exists(lpPath)) { console.log('  Open the Minecraft Launcher and log in once, then run this again.'); return; }
  try {
    app.displayDialog('Please make sure the Minecraft Launcher is CLOSED, then click OK.', { buttons: ['OK'], defaultButton: 'OK', withTitle: 'Meowcraft =^.^=' });
  } catch (e) { return; }

  // 1. Fabric loader
  say('Finding the latest Fabric loader for Minecraft ' + MC_VERSION + '...');
  const loaders = getJson('https://meta.fabricmc.net/v2/versions/loader/' + MC_VERSION);
  if (!loaders.length) { console.log("  Fabric doesn't support Minecraft " + MC_VERSION + ' yet.'); return; }
  const loader = loaders.find(l => l.loader.stable) || loaders[0];
  const loaderVer = loader.loader.version;
  const tmp = sh('mktemp').trim();
  download('https://meta.fabricmc.net/v2/versions/loader/' + MC_VERSION + '/' + loaderVer + '/profile/json', tmp);
  const versionId = JSON.parse(readText(tmp)).id;
  const verDir = mcDir + '/versions/' + versionId;
  sh('mkdir -p ' + q(verDir) + ' && mv ' + q(tmp) + ' ' + q(verDir + '/' + versionId + '.json') + ' && touch ' + q(verDir + '/' + versionId + '.jar'));
  say('Fabric loader ' + loaderVer + ' ready');

  // 2. Work out the mod list, including required dependencies.
  //    Prefers stable releases over betas, and honors exact versions that other mods ask for.
  say('Checking mods (and anything they need)...');
  function pickVersion(vs, pinId) {
    if (pinId) { const p = vs.find(v => v.id === pinId); if (p) return p; }
    return vs.find(v => v.version_type === 'release') || vs[0];
  }
  const seen = {}, chosen = {}, pins = {}, allVs = {}, slugIds = {};
  const queue = MODS.slice();
  while (queue.length) {
    const p = queue.shift();
    if (seen[p]) continue;
    seen[p] = true;
    const vs = getVersions(p, 'fabric');
    if (!vs.length) { warn(p + ' has no Fabric build for ' + MC_VERSION + ' yet - skipping'); continue; }
    const projId = vs[0].project_id;
    if (chosen[projId]) continue;
    seen[projId] = true;
    const v = pickVersion(vs, pins[projId]);
    chosen[projId] = v;
    allVs[projId] = vs;
    slugIds[p] = projId;
    (v.dependencies || []).forEach(d => {
      if (d.dependency_type !== 'required') return;
      let depProj = d.project_id;
      if (d.version_id) {
        const pv = getJson('https://api.modrinth.com/v2/version/' + d.version_id);
        depProj = pv.project_id;
        pins[depProj] = d.version_id;
        if (chosen[depProj] && chosen[depProj].id !== d.version_id) chosen[depProj] = pv;
      }
      if (depProj) queue.push(depProj);
    });
  }
  // Sodium often ships betas that the current Iris doesn't support yet.
  // If both are present, use the newest Sodium that came out before the chosen Iris.
  if (slugIds.iris && slugIds.sodium && !pins[slugIds.sodium]) {
    const irisDate = new Date(chosen[slugIds.iris].date_published);
    const ok = allVs[slugIds.sodium].filter(v => new Date(v.date_published) <= irisDate);
    if (ok.length) {
      chosen[slugIds.sodium] = ok.find(v => v.version_type === 'release') || ok[0];
      say('Matched Sodium to Iris: ' + chosen[slugIds.sodium].version_number);
    }
  }
  const want = {};   // filename -> url
  Object.keys(chosen).forEach(k => { const f = primaryFile(chosen[k]); want[f.filename] = f.url; });

  // 3. Sync the mods folder (only touches files this installer put there)
  sh('mkdir -p ' + q(modsDir));
  const owned = exists(ownedPath) ? readText(ownedPath).split('\n').filter(Boolean) : [];
  owned.forEach(old => { if (!(old in want)) { sh('rm -f ' + q(modsDir + '/' + old)); say('Removed ' + old); } });
  Object.keys(want).forEach(name => {
    const dest = modsDir + '/' + name;
    if (exists(dest)) { say('Up to date: ' + name); return; }
    download(want[name], dest);
    say('Downloaded ' + name);
  });
  writeText(ownedPath, Object.keys(want).join('\n') + '\n');

  // 4. Resource packs
  sh('mkdir -p ' + q(packDir));
  KNOWN_PACKS.forEach(pack => {
    if (PACKS.indexOf(pack) < 0 && exists(packDir + '/' + pack + '.zip')) {
      sh('rm -f ' + q(packDir + '/' + pack + '.zip')); setPackEnabled(pack + '.zip', false); say('Removed resource pack ' + pack);
    }
  });
  PACKS.forEach(pack => {
    const vs = getVersions(pack, 'minecraft');
    if (!vs.length) { warn(pack + ' has no version for ' + MC_VERSION + ' yet - skipping'); return; }
    download(primaryFile(vs[0]).url, packDir + '/' + pack + '.zip');
    setPackEnabled(pack + '.zip', true);
    say('Installed and turned on resource pack ' + pack);
  });

  // 4b. Shader packs (Iris)
  if (SHADERS.length) {
    const shDir = gameDir + '/shaderpacks';
    sh('mkdir -p ' + q(shDir));
    SHADERS.forEach(([slug, fname]) => {
      let vs = getVersions(slug, 'iris');
      if (!vs.length) {   // shader packs usually work across versions, so fall back to the newest one
        try { vs = getJson('https://api.modrinth.com/v2/project/' + slug + '/version?loaders=' + encodeURIComponent('["iris"]')); } catch (e) { vs = []; }
      }
      if (!vs.length) { warn("Couldn't find shader pack " + slug + ' - skipping'); return; }
      download(primaryFile(pickVersion(vs, null)).url, shDir + '/' + fname);
      say('Installed shader pack: ' + fname);
    });
    const cfgDir = gameDir + '/config';
    sh('mkdir -p ' + q(cfgDir));
    const irisCfg = cfgDir + '/iris.properties';
    let lines = exists(irisCfg) ? readText(irisCfg).split('\n').filter(l => l !== '') : [];
    if (!lines.some(l => /^shaderPack=.+/.test(l))) {
      lines = lines.filter(l => !/^(shaderPack|enableShaders)=/.test(l));
      lines.push('shaderPack=' + DEFAULT_SHADER, 'enableShaders=true');
      writeText(irisCfg, lines.join('\n') + '\n');
      say('Turned on shaders: ' + DEFAULT_SHADER);
    }
  }

  // 5. Server list (only if they don't have one yet)
  if (!exists(gameDir + '/servers.dat')) { sh('cp ' + q(here + '/servers.dat') + ' ' + q(gameDir + '/servers.dat')); say('Added Meowcraft to your server list'); }

  // 6. Launcher profile
  sh('cp ' + q(lpPath) + ' ' + q(lpPath + '.meowcraft-backup'));
  const lp = JSON.parse(readText(lpPath));
  lp.profiles = lp.profiles || {};
  const now = new Date().toISOString();
  lp.profiles.meowcraft = { name: 'Meowcraft', type: 'custom', created: now, lastUsed: now, lastVersionId: versionId, gameDir: gameDir, icon: ICON };
  writeText(lpPath, JSON.stringify(lp, null, 2));
  say('Meowcraft profile added to the Minecraft Launcher');

  console.log('\n  All done! Open the Minecraft Launcher, pick "Meowcraft" next to the Play button, and hit Play.');
  console.log('  In game: Multiplayer -> Meowcraft is already in your list. Press V for voice chat.\n');
}
