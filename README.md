# DibsUI

A World of Warcraft Forever addon that replaces the player and target frames with a single winged layout: your health on the left, your target on the right, and an orb in the middle for your power and casts.

![DibsUI showing player health, target health and power, the power orb and a cast in progress](screenshots/dibsui.png)

*Captured in the [UIForever](https://uiforever.com/) simulator at 2x scale, with health, target and cast values set by hand to show every field.*

## Features

**Player bar (left)**
- Health fills from the orb outwards, showing the deficit on the left and current health on the right
- Class-colored name and yellow level above the bar

**Target bars (right)**
- Health shown as `70% - 13k`, plus a smaller power bar with its amount
- Health bars and names are class colored for friendly players, and health bars are reaction colored for everyone else
- Friendly NPC names use reaction color, and other names are white
- Level at the top right, colored grey, green, yellow, orange or red by difficulty
- Hidden when you have no target

**Orb (center)**
- Fills from the bottom with your power, colored by power type, with the amount in the middle
- Numbers are shortened: `999`, `1.2k`, `12k`, `1.2m`

**Cast ring**
- Fills clockwise around the orb while casting, and drains clockwise while channeling
- Shows a round spell icon, the spell name and `current / total` time below the orb

**Clicks**
- Left-click a bar to target that unit, and right-click for its menu

## Installation

Copy the `DibsUI` folder into your game's `_forever_/Interface/AddOns/` folder, then restart the game or type `/reload`.

The other files in this repository aren't needed in-game.

## Settings

Type `/dibsui` to open the settings window.

| Setting | What it does |
|---|---|
| Lock position | Uncheck it to show a drag handle and move the frames. Bars don't respond to clicks until you lock it again. |
| Scale | Scales everything from 0.50 to 2.00. Use the slider, or type an exact value and press Enter. |

Settings are saved per account, and can't be changed during combat.

## Status

Early development, for interface version 16001.

So far DibsUI has been tested in the UIForever simulator and with offline checks, not in the live game. Behavior that depends on the real client, such as secret health and power values in combat, still needs checking in-game.

## Known limitations

Hiding Blizzard's target frame also hides everything attached to it:
- Target buffs and debuffs
- Target of target
- Rogue and druid combo points

Also:
- Pet and class resource bars still sit where Blizzard's player frame was
- In a vehicle, the bars keep showing your character

## License

[MIT](LICENSE)
