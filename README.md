# DibsUI

A World of Warcraft Forever addon that replaces the player, pet and target frames with a single winged layout: your health and your pet on the left, your target on the right, and an orb in the middle for your power and casts.

![DibsUI showing pet health, player health, target health and power, the power orb and a cast in progress](screenshots/dibsui.png)

*Captured in the [UIForever](https://uiforever.com/) simulator at 2x scale and full combat opacity, with health, power, pet, target and cast values set by hand to show every field.*

## Features

**Player bar (left)**
- Health fills from the orb outwards, with current health on the right
- Health deficit on the left, hidden at full health
- Class-colored name and yellow level above the bar

**Pet bar (far left)**
- Sits against the end of the player bar, and only shows when you have a pet
- Name and yellow level above the bar
- Current and maximum health in the center, while your mouse is over the bar
- Happiness face at the bottom left for hunter pets, with Blizzard's tooltip

**Target bars (right)**
- Slide out from under the orb when you select a target, and back in when you clear it
- Health shown as `70% - 13k`, plus a smaller power bar with its amount
- Health bars and names are class colored for friendly players, and health bars are reaction colored for everyone else
- Friendly NPC names use reaction color, and other names are white
- Level at the top right, colored grey, green, yellow, orange or red by difficulty

**Orb (center)**
- Fills from the bottom with your power, colored by power type, with the amount in the middle
- Numbers are shortened: `999`, `1.2k`, `12k`, `1.2m`

**Cast ring**
- Fills clockwise around the orb while casting, and drains clockwise while channeling
- Shows a round spell icon, the spell name and `current / total` time below the orb
- Runs in grey for your main hand swing timer when you aren't casting

**Opacity**

| State | Opacity |
|---|---|
| In combat | 100% |
| Out of combat, targeting an attackable unit | 60% |
| Out of combat, with health below full, or power away from its idle level | 60% |
| Otherwise, out of combat | 30% |

Rage idles at 0, and other power types idle at full. Casts always show at 100%, whatever the rest of the frame is doing.

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
| Width | Sets the length of the player and target bars from 0.50 to 2.00. Use the slider, or type an exact value and press Enter. |
| Pet width | Sets the length of the pet bar from 0.50 to 2.00. Use the slider, or type an exact value and press Enter. |
| Center horizontally | Centers the orb on the screen, keeping its height. The pet bar doesn't change where the center is. |
| Up, Down, Left, Right | Moves the frames one screen pixel. These and Center work whether or not the position is locked. |

Settings are saved per account, and can't be changed during combat.

## Status

Early development, for interface version 16001.

So far DibsUI has been tested in the UIForever simulator and with offline checks, not in the live game. Behavior that depends on the real client, such as secret health and power values in combat, real swing timer events and a real pet, still needs checking in-game.

## Known limitations

Hiding Blizzard's target frame also hides everything attached to it:
- Target buffs and debuffs
- Target of target
- Rogue and druid combo points

Also:
- Totem and class resource bars still sit where Blizzard's player frame was
- In a vehicle, the bars keep showing your character
- Only the main frames are kept on screen when dragging, so the pet bar can go past the left edge
- Fills start outside the orb's ring, so a nearly empty health bar looks slightly fuller than it is
- If health and power are both secret values out of combat, only health can affect opacity

## License

[MIT](LICENSE)
