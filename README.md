# Meowcraft =^.^=

The master list for the Meowcraft server: every client mod, resource pack, shader and server plugin, plus the tools that install and update them.

| File | What it is |
| --- | --- |
| `meowcraft.json` | **The master list.** Edit this to add or remove anything. Bump `"pack"` each time. |
| `meowcraft-tools/` | The `meowcraft` command for friends' computers (Windows + Mac), plus the one-line setups. |
| `meowcraft-tools/servers.dat` | The server list friends start with (just the Meowcraft server). |
| `meowcraft-server-tools/meowcraft.py` | The `meowcraft` command for the Pi: checks and updates server plugins. |
| `meowcraft-server-tools/datapacks/` | Backup copy of the silly stats datapack. |
| `.github/scripts/build-mrpack.py` | Builds the `.mrpack` downloads for the Releases page (GitHub runs it for you). |

## For friends: setting up Meowcraft (once)

First open the Minecraft Launcher, log in, then close it. Then paste ONE line and press Enter:

**Windows:** open **PowerShell** (Start menu, type "PowerShell") and paste:
```
irm https://raw.githubusercontent.com/pattyryke/meowcraft/main/meowcraft-tools/get-windows.ps1 | iex
```

**Mac:** open **Terminal** (Cmd+Space, type "Terminal") and paste:
```
curl -fsSL https://raw.githubusercontent.com/pattyryke/meowcraft/main/meowcraft-tools/get-mac.sh | bash
```

It asks Normal or Fancy, installs everything, and adds a cat **Play Meowcraft** icon (Windows: desktop, Mac: Dock).
**From then on, always start Minecraft with that icon.** It grabs any new mods in a few seconds, then opens the Launcher.

### Using another launcher instead (Modrinth App, Prism, ATLauncher)

Download **Meowcraft-Normal.mrpack** or **Meowcraft-Fancy.mrpack** from the newest
[release](https://github.com/pattyryke/meowcraft/releases/latest) and import it in your launcher.
GitHub rebuilds them by itself every time `meowcraft.json` changes. These don't auto-update like the icon does:
when the pack number goes up, import the new file again (or use your launcher's "update modpack" button).

### The meowcraft command

The icon is all most people need. For everything else, type these in a new PowerShell / Terminal window:

| Command | What it does |
| --- | --- |
| `meowcraft play` | What the icon does: quick update check, then opens the Launcher |
| `meowcraft update` | Check for new mods right now |
| `meowcraft status` | What you have, and whether an update is waiting |
| `meowcraft switch normal` / `switch fancy` | Change versions |
| `meowcraft reset` | Start the Meowcraft folder over with fresh mods. Worlds and screenshots are always kept. |
| `meowcraft reset --keep_settings` | Same, but also keeps game settings + keybinds, mod settings, minimap waypoints and the server list |
| `meowcraft upgrade` | Windows only: get the newest version of the `meowcraft` command now (Play also offers it). Macs update it on their own. |
| `meowcraft uninstall` | Remove the icon, the Launcher profile and the command (the game folder stays) |

Reset moves everything it doesn't keep into `.minecraft/meowcraft-old` (Mac: `minecraft/meowcraft-old`) until the next reset, so nothing is lost by accident.
Everything lives in a `.meowcraft` folder in your home folder.

## Update night (Patrick)

1. Edit `meowcraft.json` on GitHub and add 1 to `"pack"`. Commit.
   GitHub checks the file for typos right away. A green ✓ next to your commit means it's good. A red ✗ (plus an email)
   means there's a mistake, usually a missing or extra comma. Click the ✗ to see the exact line, and fix it before step 2.
   Until it's fixed, friends just keep playing with what they have, and nothing breaks.
2. On the Pi, stop the server in Crafty, make a backup, then: `meowcraft update`
3. Start the server. Post: "Meowcraft updated, just play like normal =^.^="

Friends get it automatically the next time they click the icon. Anyone who forgets can still join, they just
miss the new stuff. The Launcher profile shows the pack number (`Meowcraft · pack 5`), so it's easy to tell who's behind.

## Changing the meowcraft command itself

Friends' computers only pick up a new version of the `meowcraft` command when the **`stable`** branch moves,
so half-finished changes on `main` never reach anyone. (The mod list, `meowcraft.json`, still comes straight from `main`.)

1. Make the change on `main` (or a pull request) and add 0.1 to `$ToolVersion` / `TOOL_VERSION` at the top of the script.
2. GitHub tests both commands automatically (the "Test the meowcraft command" check). Wait for the green ✓.
3. Then send it to everyone: on GitHub, go to **Branches**, and update `stable` to match `main`, or on the Pi:
   `git push origin main:stable`

Windows asks friends before swapping in the new version (it runs from the next launch). Macs update quietly.

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
| `hangar` | `project` (name from the Hangar link) | `{ "name": "Timberella", "source": "hangar", "project": "timberella", "jar": "^timberella" }` |
| `github` | `repo` + `asset` (pattern for the jar in the release) | `{ "name": "EssentialsX", "source": "github", "repo": "EssentialsX/Essentials", "asset": "^EssentialsX-[0-9].*\\.jar$", "jar": "^EssentialsX-[0-9]" }` |

`jar` is the start of the plugin's file name in your `plugins` folder. That's how the tool recognizes what's installed.

**New Minecraft version:** change `"minecraft"` at the top of `meowcraft.json` (and bump `"pack"`). Run `ready` first, though (below).

## The Pi command

On the Pi this repo lives in `~/docker/meowcraft/tools`, next to Crafty in `~/docker/meowcraft/crafty`. Spare plugin jars can sit in `tools/plugins/` (they aren't uploaded).

One time, on the Pi:
```
git clone https://github.com/pattyryke/meowcraft ~/docker/meowcraft/tools      # skip if it's already there
python3 ~/docker/meowcraft/tools/meowcraft-server-tools/meowcraft.py setup
source ~/.bashrc
```
After that, from anywhere:

| Command | What it does |
| --- | --- |
| `meowcraft status` | Which server plugins are out of date: ✓ up to date · ⬆ update available · + listed but not installed · … no build yet. Also lists jars that aren't in `meowcraft.json`. |
| `meowcraft update` | Same report, then asks before downloading. Old jars go to `plugins/_old/<date>/` so you can undo. Stop the server in Crafty first. |
| `meowcraft ready 26.4` | Checks every client mod, resource pack, shader and server plugin for a new Minecraft version: "25 of 28 ready." |

- Every command pulls the newest `meowcraft.json` from GitHub first, so there's no separate `git pull` step.
- It finds the Crafty plugins folder by itself (asks once if there's more than one server) and remembers it.
  Use `--plugins <folder>` to point it somewhere else.
- If Crafty owns the plugins folder, it asks for your password and re-runs with `sudo` on its own.
- To remove a plugin: delete its line from `meowcraft.json`, then move its jar out of the plugins folder (the tool never deletes plugins).

## Notes
- The tool prefers stable releases over betas, everywhere.
- GitHub releases (like EssentialsX) don't say which Minecraft version they support, so the tool flags them for you to double-check.
- ClientSort Paper is the server half of the ClientSort mod, which everyone gets. Players without the mod can still sort with Shift + right-click on an empty slot, or `/sort`.
- Spark is built into Purpur, so it isn't listed. The silly stats datapack is listed under `server.datapacks` for reference only. It's a custom file, not downloaded.
