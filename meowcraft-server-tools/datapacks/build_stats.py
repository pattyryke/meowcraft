#!/usr/bin/env python3
"""Builds meowcraft_stats.zip (the Meowcraft Silly Stats datapack) from the list below.

Edit ACHIEVEMENTS (or STATS) and run:  python3 build_stats.py
Then copy meowcraft_stats.zip into the world's datapacks folder and run "reload" in the console.
"""
import json, os, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))

# Stats: objective, Minecraft criterion, label, colour, unit shown in /trigger mystats, divisor for display
# (the first six are the originals; their display objectives are converted by update.mcfunction)
STATS = [
    # key      shown objective  raw objective  criterion                                   label            colour     unit
    ("fall",   "mc_fall",   "mc_fall_cm",  "minecraft.custom:minecraft.fall_one_cm",          "Faceplant",     "#FF8FB1", "blocks fallen"),
    ("sneak",  "mc_sneak",  "mc_sneak_t",  "minecraft.custom:minecraft.sneak_time",           "Gremlin Mode",  "#7FE0A8", "sec sneaking"),
    ("nap",    "mc_nap",    "mc_nap_t",    "dummy",                                           "Nap Time",      "#B9A3FF", "sec asleep"),
    ("jump",   "mc_jumps",  None,          "minecraft.custom:minecraft.jump",                 "Bunny Hops",    "#FFB38A", "jumps"),
    ("dirt",   "mc_dirt",   None,          "minecraft.picked_up:minecraft.dirt",              "Dirt Hoarder",  "#E0B07A", "dirt collected"),
    ("drop",   "mc_drops",  None,          "minecraft.custom:minecraft.drop",                 "Butterfingers", "#FFE27A", "items dropped"),
    # new (2026-11-20) - these count from the day they were added
    ("lives",  "mc_deaths", None,          "minecraft.custom:minecraft.deaths",               "Nine Lives",    "#FF6B6B", "deaths"),
    ("fish",   "mc_fish",   None,          "minecraft.custom:minecraft.fish_caught",          "Fish Whisperer","#6EC6FF", "fish caught"),
    ("cake",   "mc_cake",   None,          "minecraft.custom:minecraft.eat_cake_slice",       "Cake Time",     "#FFC2E2", "cake slices"),
    ("bred",   "mc_bred",   None,          "minecraft.custom:minecraft.animals_bred",         "Matchmaker",    "#FF9ECF", "animals bred"),
    ("creeper","mc_creeper",None,          "minecraft.killed_by:minecraft.creeper",           "Creeper Hugs",  "#7CD992", "creeper deaths"),
    ("trade",  "mc_trades", None,          "minecraft.custom:minecraft.traded_with_villager", "Haggler",       "#5BE3B0", "villager trades"),
    ("puffer", "mc_puffer", None,          "minecraft.used:minecraft.pufferfish",             "Bad Sushi",     "#FFD166", "pufferfish eaten"),
]

# Achievements: id, stat key, threshold, title, chat message (after the player's name), trophy item (tier 2), secret?
ACHIEVEMENTS = [
    ("fall1",  "fall",   500,   "Professional Faceplanter", " has fallen 500 blocks. Gravity: 1, them: 0.", None),
    ("fall2",  "fall",   5000,  "Gravity's Favorite Toy",   " has fallen 5,000 blocks. The ground knows them by name.", "feather"),
    ("sneak1", "sneak",  600,   "Certified Gremlin",        " has sneaked for 10 whole minutes. What are they hiding?", None),
    ("sneak2", "sneak",  3600,  "Shadow Goblin Supreme",    " has sneaked for an HOUR. Nobody has seen their face in weeks.", "ink_sac"),
    ("nap1",   "nap",    60,    "Power Napper",             " has spent a full minute asleep. Very cat of them.", None),
    ("nap2",   "nap",    300,   "Professional Cat Napper",  " has napped for 5 minutes total. Peak cat behavior.", "white_wool"),
    ("jump1",  "jump",   1000,  "Bunny in Training",        " has jumped 1,000 times. Boing.", None),
    ("jump2",  "jump",   10000, "Hop Lord",                 " has jumped 10,000 times. Their knees have filed a complaint.", "rabbit_foot"),
    ("dirt1",  "dirt",   500,   "Dirt Enthusiast",          " has collected 500 dirt. For what purpose??", None),
    ("dirt2",  "dirt",   5000,  "Supreme Dirt Lord",        " has hoarded 5,000 dirt. Please seek help.", "dirt"),
    ("drop1",  "drop",   100,   "Butterfingers",            " has dropped 100 items. Hold onto things!", None),
    ("drop2",  "drop",   1000,  "Slippery Paws",            " has dropped 1,000 items. Paws are not hands.", "gold_ingot"),
    # new
    ("lives1", "lives",  9,     "Used Up All Nine Lives",   " has died 9 times. Cats only get nine, you know.", None),
    ("lives2", "lives",  100,   "Professional Respawner",   " has died 100 times. The respawn button is worn smooth.", "bone"),
    ("fish1",  "fish",   25,    "Fish Whisperer",           " has caught 25 fish. A true cat at heart.", None),
    ("fish2",  "fish",   250,   "The Ocean Fears Them",     " has caught 250 fish. The fish have started a support group.", "cod"),
    ("cake1",  "cake",   10,    "Cake Enthusiast",          " has eaten 10 slices of cake. Was it a birthday? Every day is a birthday.", None),
    ("cake2",  "cake",   100,   "The Cake Is Not a Lie",    " has eaten 100 slices of cake. Somebody stop them.", "cake"),
    ("bred1",  "bred",   25,    "Matchmaker",               " has bred 25 animals. Love is in the air.", None),
    ("bred2",  "bred",   250,   "Cupid",                    " has bred 250 animals. The farm is getting crowded.", "poppy"),
    ("creeper1","creeper",3,    "Creeper Hugger",           " has been blown up by creepers 3 times. They just wanted a hug.", None),
    ("creeper2","creeper",25,   "Creeper's Best Friend",    " has been blown up by creepers 25 times. At this point it's personal.", "gunpowder"),
    ("trade1", "trade",  50,    "Haggler",                  " has traded with villagers 50 times. Hmm.", None),
    ("trade2", "trade",  500,   "Emerald Goblin",           " has traded with villagers 500 times. HMMMM.", "emerald"),
    ("puffer1","puffer", 1,     "Bad Sushi",                " ate a pufferfish. Why would you do that.", None),
]
# Chat colour for each stat's title announcement (the first six match the originals)
CHAT_COLOR = {"fall": "red", "sneak": "dark_green", "nap": "aqua", "jump": "light_purple", "dirt": "gold", "drop": "yellow",
              "lives": "dark_red", "fish": "blue", "cake": "light_purple", "bred": "red", "creeper": "green",
              "trade": "dark_aqua", "puffer": "gold"}
SECRET = {"puffer1"}   # shown as ??? in /trigger achievements until earned

# Rewards: tier 1 (and the secret one) = 5 XP levels + 8 cookies. Tier 2 = 15 XP levels + a glowing trophy item.
TIER1_XP, TIER2_XP = 5, 15

stat = {s[0]: s for s in STATS}
files = {}
def put(path, lines):
    files[path] = "\n".join(lines) + "\n"
def j(x):
    return json.dumps(x, ensure_ascii=False)
def snbt_text(text, color):
    return '{text:%s,color:"%s",italic:false}' % (json.dumps(text, ensure_ascii=False), color)

# ---- load ----
load = ["# Meowcraft Silly Stats - runs on server start and /reload", "",
        "# Raw stats (counted by Minecraft itself)"]
for key, shown, raw, crit, label, col, unit in STATS:
    if raw:
        load.append(f"scoreboard objectives add {raw} {crit}")
    else:
        load.append(f"scoreboard objectives add {shown} {crit} {j({'text': label, 'color': col, 'bold': True})}")
load += ["", "# Friendly display versions (converted units)"]
for key, shown, raw, crit, label, col, unit in STATS:
    if raw:
        load.append(f"scoreboard objectives add {shown} dummy {j({'text': label, 'color': col, 'bold': True})}")
load += ["", "# Helpers", "scoreboard objectives add mc_sys dummy", "scoreboard objectives add mystats trigger",
         "scoreboard objectives add achievements trigger",
         "scoreboard players set #100 mc_sys 100", "scoreboard players set #20 mc_sys 20", "scoreboard players set #6 mc_sys 6", "",
         "# --- Cute sidebar styling ---", "scoreboard players reset meow_footer", "scoreboard players reset meow_space_bottom"]
icons = {"fall": "☁", "sneak": "✦", "nap": "☾", "jump": "❀", "dirt": "✿", "drop": "♥"}
for key, shown, raw, crit, label, col, unit in STATS[:6]:
    ic = icons[key]
    load += [
        f'scoreboard objectives modify {shown} displayname ["", {{"text": "{ic} ", "color": "white"}}, {{"text": "{label}", "color": "{col}", "bold": true}}, {{"text": " {ic}", "color": "white"}}]',
        f'scoreboard objectives modify {shown} numberformat styled {{"color": "{col}", "bold": true}}',
        f"scoreboard players set meow_space_top {shown} 2147483647",
        f'scoreboard players display name meow_space_top {shown} {{"text":" "}}',
        f"scoreboard players display numberformat meow_space_top {shown} blank"]
load += ["", "# No sidebar - tab list shows blocks fallen", "scoreboard objectives setdisplay sidebar",
         "scoreboard objectives setdisplay list mc_fall", "", "# Start the loops",
         "schedule function meowcraft:nap_check 5t replace", "schedule function meowcraft:update 1s replace",
         "schedule clear meowcraft:rotate"]
put("data/meowcraft/function/load.mcfunction", load)

# ---- update (every second) ----
put("data/meowcraft/function/update.mcfunction", [
    "# Every second: convert units, check titles and rewards, handle /trigger mystats and /trigger achievements",
    "execute as @a run scoreboard players operation @s mc_fall = @s mc_fall_cm",
    "scoreboard players operation @a mc_fall /= #100 mc_sys",
    "execute as @a run scoreboard players operation @s mc_sneak = @s mc_sneak_t",
    "scoreboard players operation @a mc_sneak /= #20 mc_sys",
    "execute as @a run scoreboard players operation @s mc_nap = @s mc_nap_t",
    "scoreboard players operation @a mc_nap /= #20 mc_sys", "",
    "function meowcraft:check_titles",
    "function meowcraft:check_rewards",
    "function meowcraft:catnames", "",
    "scoreboard players enable @a mystats",
    "execute as @a[scores={mystats=1..}] run function meowcraft:mystats",
    "scoreboard players enable @a achievements",
    "execute as @a[scores={achievements=1..}] run function meowcraft:achievements", "",
    "schedule function meowcraft:update 1s replace"])

# ---- titles + rewards ----
check = ["# Award each title once per player (tags remember who has it)"]
rew = ["# Give each title's reward once. Also catches up anyone who earned a title before rewards existed."]
for aid, key, thr, title, msg, trophy in ACHIEVEMENTS:
    shown = stat[key][1]; col = stat[key][5]
    check.append(f"execute as @a[tag=!mc_t_{aid}] if score @s {shown} matches {thr}.. run function meowcraft:titles/{aid}")
    rew.append(f"execute as @a[tag=mc_t_{aid},tag=!mc_r_{aid}] run function meowcraft:rewards/{aid}")
    put(f"data/meowcraft/function/titles/{aid}.mcfunction", [
        f"tag @s add mc_t_{aid}",
        "tellraw @a " + j(["", {"text": "[Meowcraft] ", "color": "dark_purple"}, {"selector": "@s", "color": CHAT_COLOR[key]}, {"text": msg, "color": "white"}]),
        "tellraw @a " + j(["", {"text": "   New title: ", "color": "gray"}, {"text": title, "color": CHAT_COLOR[key], "bold": True}]),
        "execute as @a at @s run playsound minecraft:entity.cat.ambient master @s ~ ~ ~ 1 1"])
    if trophy:
        give = [f"xp add @s {TIER2_XP} levels",
                f"give @s minecraft:{trophy}[custom_name={snbt_text(title + ' Trophy', col)},"
                f"lore=[{snbt_text('A Meowcraft title trophy =^.^=', 'gray')}],enchantment_glint_override=true]"]
        what = f"{TIER2_XP} XP levels and a {title} Trophy"
    else:
        give = [f"xp add @s {TIER1_XP} levels",
                f"give @s minecraft:cookie[custom_name={snbt_text('Meowcraft Treat', '#FFB38A')}] 8"]
        what = f"{TIER1_XP} XP levels and 8 Meowcraft Treats"
    put(f"data/meowcraft/function/rewards/{aid}.mcfunction", [f"tag @s add mc_r_{aid}"] + give + [
        "tellraw @s " + j(["", {"text": "   Reward for ", "color": "gray"}, {"text": title, "color": CHAT_COLOR[key]},
                            {"text": ": " + what + "!", "color": "gray"}]),
        "playsound minecraft:entity.player.levelup master @s ~ ~ ~ 1 1.4"])
put("data/meowcraft/function/check_titles.mcfunction", check)
put("data/meowcraft/function/check_rewards.mcfunction", rew)

# ---- /trigger achievements ----
ach = ["# Private list of every achievement for whoever ran /trigger achievements",
       "tellraw @s " + j(["", {"text": "=^.^= ", "color": "#B9A3FF"}, {"selector": "@s", "color": "light_purple"},
                          {"text": "'s Achievements =^.^=", "color": "#B9A3FF"}])]
for aid, key, thr, title, msg, trophy in ACHIEVEMENTS:
    shown, unit = stat[key][1], stat[key][6]
    got = ["", {"text": " ✔ ", "color": "green"}, {"text": title, "color": "gold", "bold": True}]
    if aid in SECRET:
        todo = ["", {"text": " ☐ ", "color": "dark_gray"}, {"text": "??? (secret)", "color": "dark_gray"}]
    else:
        todo = ["", {"text": " ☐ ", "color": "dark_gray"}, {"text": title, "color": "gray"},
                {"text": "  ", "color": "dark_gray"}, {"score": {"name": "@s", "objective": shown}, "color": "dark_gray"},
                {"text": f"/{thr:,} {unit}", "color": "dark_gray"}]
    ach.append(f"execute if entity @s[tag=mc_t_{aid}] run tellraw @s {j(got)}")
    ach.append(f"execute unless entity @s[tag=mc_t_{aid}] run tellraw @s {j(todo)}")
ach += ["tellraw @s " + j({"text": " Tier 1: 5 XP levels + treats. Tier 2: 15 XP levels + a glowing trophy.", "color": "dark_gray", "italic": True}),
        "scoreboard players set @s achievements 0"]
put("data/meowcraft/function/achievements.mcfunction", ach)

# ---- /trigger mystats ----
ms = ["# Private stat card for whoever ran /trigger mystats",
      "tellraw @s " + j(["", {"text": "=^.^= ", "color": "#B9A3FF"}, {"selector": "@s", "color": "light_purple"}, {"text": "'s Silly Stats =^.^=", "color": "#B9A3FF"}])]
for key, shown, raw, crit, label, col, unit in STATS:
    if key == "puffer":
        continue
    ms.append("tellraw @s " + j(["", {"text": f" {label}: ", "color": col}, {"score": {"name": "@s", "objective": shown}}, {"text": f" {unit}", "color": "gray"}]))
ms += ["tellraw @s " + j({"text": " See every achievement: /trigger achievements", "color": "dark_gray", "italic": True}),
       "scoreboard players set @s mystats 0"]
put("data/meowcraft/function/mystats.mcfunction", ms)

# ---- uninstall ----
un = ["# Removes everything this datapack added. Run, then: datapack disable \"file/meowcraft_stats.zip\"",
      "schedule clear meowcraft:nap_check", "schedule clear meowcraft:update", "schedule clear meowcraft:rotate"]
for key, shown, raw, *_ in STATS:
    if raw: un.append(f"scoreboard objectives remove {raw}")
    un.append(f"scoreboard objectives remove {shown}")
un += ["scoreboard objectives remove mc_sys", "scoreboard objectives remove mystats", "scoreboard objectives remove achievements"]
for aid, *_ in ACHIEVEMENTS:
    un += [f"tag @a remove mc_t_{aid}", f"tag @a remove mc_r_{aid}"]
put("data/meowcraft/function/uninstall.mcfunction", un)

# ---- unchanged originals ----
SRC = os.path.join(HERE, "meowcraft_stats_src")
keep = ["pack.mcmeta", "data/minecraft/tags/function/load.json", "data/meowcraft/function/rotate.mcfunction",
        "data/meowcraft/function/catnames.mcfunction", "data/meowcraft/function/nap_check.mcfunction"]
for k in keep:
    files[k] = open(os.path.join(SRC, k), encoding="utf-8").read()

out = os.path.join(HERE, "meowcraft_stats.zip")
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for path in sorted(files):
        z.writestr(path, files[path])
print(f"Built {out}: {len(ACHIEVEMENTS)} achievements, {len(STATS)} stats, {len(files)} files")
