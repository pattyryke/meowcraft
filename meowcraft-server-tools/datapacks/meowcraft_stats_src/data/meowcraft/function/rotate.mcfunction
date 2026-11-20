# Every 15 seconds: show the next silly stat on the sidebar
scoreboard players add #rot mc_sys 1
scoreboard players operation #rot mc_sys %= #6 mc_sys
execute if score #rot mc_sys matches 0 run scoreboard objectives setdisplay sidebar mc_fall
execute if score #rot mc_sys matches 1 run scoreboard objectives setdisplay sidebar mc_sneak
execute if score #rot mc_sys matches 2 run scoreboard objectives setdisplay sidebar mc_nap
execute if score #rot mc_sys matches 3 run scoreboard objectives setdisplay sidebar mc_jumps
execute if score #rot mc_sys matches 4 run scoreboard objectives setdisplay sidebar mc_dirt
execute if score #rot mc_sys matches 5 run scoreboard objectives setdisplay sidebar mc_drops
schedule function meowcraft:rotate 15s replace
