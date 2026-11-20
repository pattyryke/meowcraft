#!/usr/bin/env python3
"""Builds Meowcraft-Normal.mrpack and Meowcraft-Fancy.mrpack from meowcraft.json.

A .mrpack is a Modrinth modpack: a small zip with a list of download links (no mod files inside),
so it can be imported with one click into the Modrinth App, Prism Launcher, ATLauncher and others.
GitHub runs this automatically (the "Build the pack downloads" workflow) and puts the files on the
Releases page. It picks the same versions the meowcraft command does:
stable releases first, exact versions other mods ask for, and the Sodium that matches Iris.

    python3 .github/scripts/build-mrpack.py [--out dist]
"""
import argparse
import hashlib
import io
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODRINTH = os.environ.get("MEOWCRAFT_MODRINTH", "https://api.modrinth.com")
FABRIC = os.environ.get("MEOWCRAFT_FABRIC", "https://meta.fabricmc.net")
UA = "meowcraft-pack-builder (github.com/pattyryke/meowcraft)"


def get(url, allow_404=False):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.read()
    except urllib.error.HTTPError as e:
        if allow_404 and e.code == 404:
            return None
        raise SystemExit(f"Couldn't download {url} ({e.code})")


def get_json(url, allow_404=False):
    data = get(url, allow_404)
    return None if data is None else json.loads(data)


def versions(project, loaders, mc=None):
    qs = {"loaders": json.dumps(loaders)}
    if mc:
        qs["game_versions"] = json.dumps([mc])
    url = f"{MODRINTH}/v2/project/{urllib.parse.quote(project)}/version?{urllib.parse.urlencode(qs)}"
    return get_json(url, allow_404=True) or []


def primary_file(v):
    return next((f for f in v["files"] if f.get("primary")), v["files"][0])


def pick(vs, pin=None):
    if pin:
        for v in vs:
            if v["id"] == pin:
                return v
    return next((v for v in vs if v["version_type"] == "release"), vs[0])


def file_entry(path, f, sha512=None):
    hashes = {"sha1": f["hashes"]["sha1"], "sha512": sha512 or f["hashes"]["sha512"]}
    return {"path": path, "hashes": hashes, "env": {"client": "required", "server": "unsupported"},
            "downloads": [f["url"]], "fileSize": f["size"]}


def variant(m, name):
    """Mods, resource packs, shaders and default shader for one variant, following "extends"."""
    sec = m["client"][name]
    base = variant(m, sec["extends"]) if sec.get("extends") else {"mods": [], "packs": [], "shaders": [], "default": ""}
    out = {"mods": base["mods"] + [x for x in sec.get("mods", []) if x not in base["mods"]],
           "packs": base["packs"] + [x for x in sec.get("resourcepacks", []) if x not in base["packs"]],
           "shaders": base["shaders"] + sec.get("shaders", []),
           "default": sec.get("default_shader") or base["default"]}
    return out


def resolve_mods(mods, mc, warnings):
    seen, chosen, pins, all_vs, slug_ids = set(), {}, {}, {}, {}
    queue = list(mods)
    while queue:
        p = queue.pop(0)
        if p in seen:
            continue
        seen.add(p)
        vs = versions(p, ["fabric"], mc)
        if not vs:
            warnings.append(f"{p} has no Fabric build for {mc} yet - left out")
            continue
        proj = vs[0]["project_id"]
        if proj in chosen:
            continue
        seen.add(proj)
        v = pick(vs, pins.get(proj))
        chosen[proj], all_vs[proj], slug_ids[p] = v, vs, proj
        for d in v.get("dependencies") or []:
            if d.get("dependency_type") != "required":
                continue
            dep = d.get("project_id")
            if d.get("version_id"):
                pv = get_json(f"{MODRINTH}/v2/version/{d['version_id']}")
                dep = pv["project_id"]
                pins[dep] = d["version_id"]
                if dep in chosen and chosen[dep]["id"] != d["version_id"]:
                    chosen[dep] = pv
            if dep:
                queue.append(dep)
    # Same rule as the meowcraft command: use the newest Sodium released before the chosen Iris.
    iris, sodium = slug_ids.get("iris"), slug_ids.get("sodium")
    if iris and sodium and sodium not in pins:
        iris_date = chosen[iris]["date_published"]
        ok = [v for v in all_vs[sodium] if v["date_published"] <= iris_date]
        if ok:
            chosen[sodium] = pick(ok)
    return list(chosen.values())


def build(m, name, title, summary, out_dir, loader_version, warnings):
    mc, pack = m["minecraft"], m["pack"]
    v = variant(m, name)
    files = []
    for ver in resolve_mods(v["mods"], mc, warnings):
        f = primary_file(ver)
        files.append(file_entry(f"mods/{f['filename']}", f))
    for p in v["packs"]:
        vs = versions(p, ["minecraft"], mc)
        if not vs:
            warnings.append(f"resource pack {p} has no version for {mc} yet - left out")
            continue
        files.append(file_entry(f"resourcepacks/{p}.zip", primary_file(vs[0])))
    shader_files = []
    for s in v["shaders"]:
        # Shader packs usually work across versions, so fall back to the newest one (like the command does).
        vs = versions(s["project"], ["iris"], mc) or versions(s["project"], ["iris"])
        if not vs:
            warnings.append(f"shader pack {s['project']} not found - left out")
            continue
        files.append(file_entry(f"shaderpacks/{s['file']}", primary_file(vs[0])))
        shader_files.append(s["file"])
    files.sort(key=lambda e: e["path"].lower())

    index = {"formatVersion": 1, "game": "minecraft", "versionId": f"pack-{pack}",
             "name": f"Meowcraft {title}", "summary": summary, "files": files,
             "dependencies": {"minecraft": mc, "fabric-loader": loader_version}}

    path = os.path.join(out_dir, f"Meowcraft-{title}.mrpack")
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("modrinth.index.json", json.dumps(index, indent=2))
        # The server list friends start with (just the Meowcraft server).
        z.write(os.path.join(ROOT, "meowcraft-tools", "servers.dat"), "overrides/servers.dat")
        if v["packs"]:
            # Only the resource pack line: Minecraft fills in every other setting with its defaults.
            line = json.dumps(["vanilla", "fabric"] + [f"file/{p}.zip" for p in v["packs"]])
            z.writestr("overrides/options.txt", f"resourcePacks:{line}\n")
        if v["default"] and v["default"] in shader_files:
            z.writestr("overrides/config/iris.properties", f"shaderPack={v['default']}\nenableShaders=true\n")
    print(f"  {os.path.basename(path)}: {len(files)} files")
    return {"file": os.path.basename(path), "files": len(files)}


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", default="dist")
    args = ap.parse_args()
    with open(os.path.join(ROOT, "meowcraft.json"), encoding="utf-8") as fh:
        m = json.load(fh)
    os.makedirs(args.out, exist_ok=True)

    loaders = get_json(f"{FABRIC}/v2/versions/loader/{m['minecraft']}")
    if not loaders:
        raise SystemExit(f"Fabric doesn't support Minecraft {m['minecraft']} yet.")
    loader = next((l for l in loaders if l["loader"].get("stable")), loaders[0])["loader"]["version"]

    print(f"Meowcraft pack {m['pack']} for Minecraft {m['minecraft']} (Fabric {loader})")
    warnings = []
    built = [
        build(m, "core", "Normal", "Fast and smooth on any computer.", args.out, loader, warnings),
        build(m, "fancy", "Fancy", "Shaders and smoother animations. Needs a powerful computer.", args.out, loader, warnings),
    ]
    for w in dict.fromkeys(warnings):
        print(f"::warning::{w}")
    with open(os.path.join(args.out, "pack-info.json"), "w", encoding="utf-8") as fh:
        json.dump({"pack": m["pack"], "minecraft": m["minecraft"], "fabric": loader, "downloads": built}, fh, indent=2)


if __name__ == "__main__":
    main()
