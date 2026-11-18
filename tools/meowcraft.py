#!/usr/bin/env python3
"""
Meowcraft tools  =^.^=

  python3 meowcraft.py status  --plugins <plugins folder>          # what's installed vs. newest for your Minecraft version
  python3 meowcraft.py update  --plugins <plugins folder>          # same report, then asks before downloading updates
  python3 meowcraft.py ready   26.4                                # are all client mods + server plugins out for 26.4 yet?

The list of mods/plugins comes from meowcraft.json (next to this script's folder,
or pass --manifest <file or https URL>). Uses only the Python standard library.
"""
import argparse
import datetime
import json
import os
import re
import shutil
import sys
import urllib.parse
import urllib.request

UA = "pattycakez69/meowcraft-tools/1.0"
PLUGIN_LOADER_GROUPS = [["paper", "purpur"], ["spigot", "bukkit"]]

# ---------- small helpers ----------

def color(text, code):
    return f"\033[{code}m{text}\033[0m" if sys.stdout.isatty() else text

GREEN, YELLOW, RED, GRAY, PINK = "32", "33", "31", "90", "95"


def get_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def download(url, dest):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    tmp = dest + ".part"
    with urllib.request.urlopen(req, timeout=120) as r, open(tmp, "wb") as f:
        shutil.copyfileobj(r, f)
    os.replace(tmp, dest)


def vtuple(v):
    return tuple(int(x) for x in re.findall(r"\d+", v))


def mc_matches(spec, mc):
    """spec is a single version ('26.3') or a range ('26.1-26.3')."""
    spec = spec.strip()
    if "-" in spec:
        lo, hi = spec.split("-", 1)
        return vtuple(lo) <= vtuple(mc) <= vtuple(hi)
    return spec == mc


def q(obj):
    return urllib.parse.quote(json.dumps(obj))


def load_manifest(where):
    if where.startswith("http://") or where.startswith("https://"):
        return get_json(where)
    with open(where, encoding="utf-8") as f:
        return json.load(f)

# ---------- sources: each returns dict(version, file, url, note) or None ----------

def modrinth_latest(project, mc, loaders):
    url = (f"https://api.modrinth.com/v2/project/{urllib.parse.quote(project)}/version"
           f"?loaders={q(loaders)}&game_versions={q([mc])}")
    try:
        versions = get_json(url)
    except Exception as e:
        return {"error": f"Modrinth: {e}"}
    if not versions:
        return None
    v = next((x for x in versions if x.get("version_type") == "release"), versions[0])
    f = next((x for x in v["files"] if x.get("primary")), v["files"][0])
    note = "" if v.get("version_type") == "release" else v.get("version_type", "")
    return {"version": v["version_number"], "file": f["filename"], "url": f["url"], "note": note}


def modrinth_plugin(project, mc):
    for group in PLUGIN_LOADER_GROUPS:
        r = modrinth_latest(project, mc, group)
        if r:
            return r
    return None


def github_latest(repo, asset_regex):
    try:
        rel = get_json(f"https://api.github.com/repos/{repo}/releases/latest")
    except Exception as e:
        return {"error": f"GitHub: {e}"}
    pat = re.compile(asset_regex, re.I)
    for a in rel.get("assets", []):
        if pat.search(a["name"]):
            return {"version": rel.get("tag_name", "?"), "file": a["name"],
                    "url": a["browser_download_url"],
                    "note": "GitHub doesn't list Minecraft versions - check the release notes"}
    return {"error": f"no file matching {asset_regex} in {repo}'s latest release"}


def hangar_latest(project, mc):
    try:
        data = get_json(f"https://hangar.papermc.io/api/v1/projects/{urllib.parse.quote(project)}/versions"
                        f"?limit=25&offset=0&platform=PAPER")
    except Exception as e:
        return {"error": f"Hangar: {e}"}
    for v in data.get("result", []):
        specs = v.get("platformDependencies", {}).get("PAPER", [])
        if any(mc_matches(s, mc) for s in specs):
            dl = v.get("downloads", {}).get("PAPER", {})
            url = dl.get("downloadUrl") or dl.get("externalUrl")
            name = (dl.get("fileInfo") or {}).get("name") or f"{project}-{v.get('name')}.jar"
            return {"version": v.get("name", "?"), "file": name, "url": url, "note": ""}
    return None


def plugin_latest(p, mc):
    src = p.get("source")
    if src == "modrinth":
        return modrinth_plugin(p["project"], mc)
    if src == "github":
        return github_latest(p["repo"], p.get("asset", r"\.jar$"))
    if src == "hangar":
        return hangar_latest(p["project"], mc)
    return {"error": f"unknown source '{src}'"}

# ---------- commands ----------

def find_installed(plugins_dir, pattern):
    pat = re.compile(pattern, re.I)
    return sorted(f for f in os.listdir(plugins_dir) if f.lower().endswith(".jar") and pat.search(f))


def plugin_report(manifest, plugins_dir):
    mc = manifest["minecraft"]
    rows, claimed = [], set()
    for p in manifest["server"]["plugins"]:
        installed = find_installed(plugins_dir, p["jar"])
        claimed.update(installed)
        latest = plugin_latest(p, mc)
        if latest is None:
            status = ("noversion", f"no build for {mc} yet")
        elif "error" in latest:
            status = ("error", latest["error"])
        elif not installed:
            status = ("missing", "not installed")
        elif latest["file"] in installed:
            status = ("ok", "up to date")
        else:
            status = ("update", "update available")
        rows.append({"plugin": p, "installed": installed, "latest": latest, "status": status})
    untracked = sorted(f for f in os.listdir(plugins_dir)
                       if f.lower().endswith(".jar") and f not in claimed)
    return mc, rows, untracked


def print_report(mc, rows, untracked):
    print(color(f"\n  =^.^=  Meowcraft plugins for Minecraft {mc}\n", PINK))
    icons = {"ok": ("✓", GREEN), "update": ("⬆", YELLOW), "missing": ("+", YELLOW),
             "noversion": ("…", GRAY), "error": ("!", RED)}
    for r in rows:
        kind, text = r["status"]
        icon, c = icons[kind]
        inst = ", ".join(r["installed"]) or "-"
        print(color(f"  {icon} {r['plugin']['name']}", c) + color(f"  ({text})", c))
        print(color(f"      installed: {inst}", GRAY))
        if r["latest"] and "error" not in r["latest"]:
            extra = f"   [{r['latest']['note']}]" if r["latest"].get("note") else ""
            print(color(f"      newest:    {r['latest']['file']}{extra}", GRAY))
    if untracked:
        print(color("\n  Jars in your plugins folder that aren't in meowcraft.json:", YELLOW))
        for f in untracked:
            print(color(f"      {f}", YELLOW))
        print(color("  Add them to meowcraft.json (or fix a 'jar' pattern) so they're tracked.", GRAY))
    print()


def cmd_status(args, manifest):
    mc, rows, untracked = plugin_report(manifest, args.plugins)
    print_report(mc, rows, untracked)
    todo = [r for r in rows if r["status"][0] in ("update", "missing")]
    if todo:
        print(f"  {len(todo)} plugin(s) can be installed/updated. Run with 'update' to do it.\n")
    return mc, rows


def cmd_update(args, manifest):
    mc, rows = cmd_status(args, manifest)
    todo = [r for r in rows if r["status"][0] in ("update", "missing")]
    if not todo:
        print(color("  Everything is up to date. =^.^=\n", GREEN))
        return
    print(color("  Before continuing: STOP the server in Crafty and make a backup.", RED))
    names = ", ".join(r["plugin"]["name"] for r in todo)
    if not args.yes:
        answer = input(f"  Download {names}? Type yes to continue: ").strip().lower()
        if answer != "yes":
            print("  Nothing changed.")
            return
    old_dir = os.path.join(args.plugins, "_old", datetime.date.today().isoformat())
    for r in todo:
        latest = r["latest"]
        dest = os.path.join(args.plugins, latest["file"])
        print(f"  Downloading {latest['file']} ...")
        download(latest["url"], dest)
        for old in r["installed"]:
            if old != latest["file"]:
                os.makedirs(old_dir, exist_ok=True)
                shutil.move(os.path.join(args.plugins, old), os.path.join(old_dir, old))
                print(color(f"    moved old {old} to {os.path.relpath(old_dir, args.plugins)}/", GRAY))
    print(color("\n  Done! Start the server in Crafty, then run 'plugins' in its console to check.", GREEN))
    print(color("  If something breaks, move the old jar back from the _old folder.\n", GRAY))


def cmd_ready(args, manifest):
    mc = args.version
    print(color(f"\n  =^.^=  Is everything ready for Minecraft {mc}?\n", PINK))
    total, ready = 0, 0

    def line(ok, name, detail=""):
        nonlocal total, ready
        total += 1
        ready += 1 if ok else 0
        icon, c = ("✓", GREEN) if ok else ("✗", RED)
        print(color(f"    {icon} {name}", c) + (color(f"  {detail}", GRAY) if detail else ""))

    client = manifest["client"]
    seen = set()
    for variant, section in client.items():
        mods = [m for m in section.get("mods", []) if m not in seen]
        packs = section.get("resourcepacks", [])
        shaders = section.get("shaders", [])
        if not (mods or packs or shaders):
            continue
        print(color(f"  Client ({variant})", PINK))
        for m in mods:
            seen.add(m)
            r = modrinth_latest(m, mc, ["fabric"])
            line(bool(r) and "error" not in r, m, (r or {}).get("version", "") if r and "error" not in r else "")
        for p in packs:
            r = modrinth_latest(p, mc, ["minecraft"])
            line(bool(r) and "error" not in r, p + " (resource pack)")
        for s in shaders:
            r = modrinth_latest(s["project"], mc, ["iris"])
            line(bool(r) and "error" not in r, s.get("name", s["project"]) + " (shader)",
                 "" if r else "shaders usually still work - optional")
        print()
    print(color("  Server plugins", PINK))
    for p in manifest["server"]["plugins"]:
        r = plugin_latest(p, mc)
        ok = bool(r) and "error" not in r
        detail = r["note"] if ok and r.get("note") else ""
        line(ok, p["name"], detail)
    print()
    c = GREEN if ready == total else YELLOW
    print(color(f"  {ready} of {total} ready for {mc}.", c))
    if ready < total:
        print(color("  Wait for the ✗ items (or drop them) before updating Minecraft.", GRAY))
    print()


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    default_manifest = os.path.join(here, "..", "meowcraft.json")
    ap = argparse.ArgumentParser(description="Meowcraft mod & plugin tools =^.^=")
    ap.add_argument("--manifest", default=os.environ.get("MEOWCRAFT_MANIFEST", default_manifest),
                    help="meowcraft.json file or https URL")
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("status", "update"):
        s = sub.add_parser(name)
        s.add_argument("--plugins", required=True, help="the server's plugins folder")
        if name == "update":
            s.add_argument("--yes", action="store_true", help="don't ask before downloading")
    r = sub.add_parser("ready")
    r.add_argument("version", help="Minecraft version to check, e.g. 26.4")
    args = ap.parse_args()

    manifest = load_manifest(args.manifest)
    if args.cmd in ("status", "update") and not os.path.isdir(args.plugins):
        sys.exit(f"Plugins folder not found: {args.plugins}")
    {"status": cmd_status, "update": cmd_update, "ready": cmd_ready}[args.cmd](args, manifest)


if __name__ == "__main__":
    main()
