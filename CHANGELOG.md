# Changelog

## 0.1.1

- Heal and absorb prediction on the player and target health bars. Incoming heals carry on from the end of the health in a darker shade of the bar's color, with absorbs in blue after them. Neither runs past the end of the bar, and the bar's end glows when either one is cut short there
- Thanks to Alectris for his help

## 0.1.0

First public build, for WoW Forever 1.60.1.

- Winged unit frames: player, pet, target and target of target bars around a power orb
- Orb with liquid power, combo point ring, mana spark, and a cast ring that doubles as a swing timer
- Every text spot can be moved, restyled, set to show different values, or shown only on mouseover
- Opacity modes: Smart, Minimalist, Full and Manual
- Buff frames on Blizzard's aura container, so they keep updating in combat:
  - Player long buffs, with weapon enchants and a List mode
  - Player short buffs above the player bar
  - Player debuffs beside the player bar, rising above the pet bar when you have one, with debuff type borders
  - Target buffs, with a glow on buffs you can steal or purge
  - Target debuffs above the target bar, your own first and larger
- Settings window with General, Text, Buffs/Debuffs and Profiles tabs; resizable from the corner, and scrollable
- Profiles shared across the account
- `/dibsui lock` to lock or unlock the frames, and a chat line at login
- Masque support for buff icons
