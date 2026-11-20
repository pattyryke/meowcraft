# Every 5 ticks: anyone in a bed gets 5 ticks of Nap Time.
# Checks both NBT spellings so it works across versions.
execute as @a if data entity @s sleeping_pos run tag @s add mc_asleep
execute as @a if data entity @s SleepingX run tag @s add mc_asleep
scoreboard players add @a[tag=mc_asleep] mc_nap_t 5
tag @a remove mc_asleep
schedule function meowcraft:nap_check 5t replace
