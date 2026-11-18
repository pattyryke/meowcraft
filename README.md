# Meowcraft =^.^=

The master list for the Meowcraft server: every client mod, resource pack, shader and server plugin, plus the tools that install and update them.

| File | What it is |
| --- | --- |
| `meowcraft.json` | **The master list.** Edit this to add or remove anything. |
| `installer/` | The Windows + Mac client installer. It reads `meowcraft.json` from this repo, so friends always get the current list. |
| `server/meowcraft_stats.zip` | Backup copy of the silly stats datapack. |
| `tools/meowcraft.py` | Runs on the Pi. Shows which server plugins are out of date, updates them when you say so, and checks whether everything is ready for a new Minecraft version. |

## One-time setup

1. Create a **public** GitHub repo named `meowcraft` and upload everything in this folder (drag and drop on the repo page works).
2. Open `installer/manifest-url.txt` and replace `YOUR-GITHUB-NAME` with your GitHub username. Commit.
3. Re-zip the `installer` folder for friends:
   - **Core:** leave `variant.txt` as `core`.
   - **Fancy:** change `variant.txt` to `fancy`.

From then on, editing `meowcraft.json` on GitHub changes what everyone gets the next time they run the installer. No new zips needed.

## Adding or removing things

**Client mods / resource packs:** use the name from the Modrinth link. For `modrinth.com/mod/sodium`, the name is `sodium`.
- Everyone: add it to `client.core.mods`.
- Fancy only: add it to `client.fancy.mods`.
- Required libraries are pulled in automatically, so you don't need to list them.

**Shaders:** add `{ "project": "<modrinth name>", "name": "...", "file": "Meowcraft <Tier> - <Name>.zip" }` to `client.fancy.shaders`.

**Server plugins:** add an entry to `server.plugins`:

| `source` | Also needs | Example |
| --- | --- | --- |
| `modrinth` | `project` (name from the Modrinth link) | `{ "name": "Chunky", "source": "modrinth", "project": "chunky", "jar": "^Chunky" }` |
| `hangar` | `project` (name from the Hangar link) | `{ "name": "Chestsort+", "source": "hangar", "project": "chestsort", "jar": "^chestsort" }` |
| `github` | `repo` + `asset` (pattern for the jar in the release) | `{ "name": "EssentialsX", "source": "github", "repo": "EssentialsX/Essentials", "asset": "^EssentialsX-[0-9].*\\.jar$", "jar": "^EssentialsX-[0-9]" }` |

`jar` is the start of the plugin's file name in your `plugins` folder. That's how the tool recognizes what's installed.

**New Minecraft version:** change `"minecraft"` at the top of `meowcraft.json`. Run `ready` first, though (below).

## The Pi tool

Get it on the Pi once:
```
git clone https://github.com/pattyryke/meowcraft ~/meowcraft
```
Find your server's plugins folder (the long ID is your Crafty server):
```
ls ~/crafty/docker/servers/
```

**What's out of date?**
```
python3 ~/meowcraft/tools/meowcraft.py status --plugins ~/crafty/docker/servers/<id>/plugins
```
- ✓ up to date · ⬆ update available · + listed but not installed · … no build for your Minecraft version yet
- It also lists jars in your plugins folder that aren't in `meowcraft.json`, so nothing goes untracked.

**Update plugins** (stop the server in Crafty and make a backup first):
```
python3 ~/meowcraft/tools/meowcraft.py update --plugins ~/crafty/docker/servers/<id>/plugins
```
It shows the report, asks before downloading, and moves the old jars into `plugins/_old/<date>/` so you can undo.

**Ready for a new Minecraft version?**
```
python3 ~/meowcraft/tools/meowcraft.py ready 26.4
```
Checks every client mod, resource pack, shader and server plugin and gives you a score, like "25 of 28 ready."

**Get the latest list after editing on GitHub:** `cd ~/meowcraft && git pull`

If you get "Permission denied," Crafty owns the plugins folder. Run the same command with `sudo` in front.

## Notes
- The tool prefers stable releases over betas, everywhere.
- GitHub releases (like EssentialsX) don't say which Minecraft version they support, so the tool flags them for you to double-check.
- Spark is built into Purpur, so it isn't listed. The silly stats datapack is listed under `server.datapacks` for reference only. It's a custom file, not downloaded.
