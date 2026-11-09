# DibsUI

A World of Warcraft Forever addon that replaces the player, pet, target and target of target frames with a single winged layout: your health and your pet on the left, your target and its target on the right, and an orb in the middle for your power and casts.

![DibsUI showing pet health, player health, target health and power, the power orb and a cast in progress](screenshots/dibsui.png)

*Captured in the [UIForever](https://uiforever.com/) simulator at 2x scale and full combat opacity, with health, power, pet, target and cast values set by hand to show every field.*

## Features

**Player bar (left)**
- Health fills from the orb outwards, with current health on the right
- Missing health on the left, hidden at full health
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

**Target of target (far right)**
- Sits against the end of the target's health bar and slides out with it
- Name and difficulty-colored level above the bar, with the bar and name colored like the target's
- Can be turned off in the settings

**Orb (center)**
- Fills from the bottom with your power, with the amount in the middle
- Mana is a deep blue liquid that slowly swirls, and rage is thick, dark blood. Other power types are a liquid in their own color
- A thin glowing line marks the top of the liquid
- Numbers are shortened: `999`, `1.2k`, `12k`, `1.2m`
- Every text on the bars and orb can be changed or turned off in the settings

**Combo points**
- A five-segment ring on the inner edge of the orb, filling clockwise from 12 o'clock
- The first two points are yellow, the next two orange, and the last red
- Shows for rogues, and for druids in cat form, with the points on your current target

**Mana spark**
- After a successful spell that costs mana, a gold spark circles the orb's inner edge once over five seconds, showing the five second rule
- Casting again restarts it, and potions, food, wands and free spells don't start it

**Cast ring**
- Fills clockwise around the orb while casting, and drains clockwise while channeling
- Shows a round spell icon, the spell name and `current / total` time below the orb
- Runs in grey for your main hand swing timer when you aren't casting

**Player buffs**
- Replace Blizzard's buff frame with two frames: long buffs and short buffs
- Long buffs last over 2 minutes or never expire, and short buffs are everything else
- Both are built on Blizzard's own aura container, so they keep updating in combat, when addons can't read buffs themselves
- DibsUI ships a list of every long aura in the game client, taken from the client's own spell tables, so a long buff goes straight to the long buffs even the first time you get it mid-fight
- It also learns each buff's real duration whenever buffs can be read, for every character on the account, which wins over the list, so talents and hotfixes count. A buff on neither shows with the short buffs until the fight ends, then moves
- With one frame turned off, the other shows every buff
- Long buffs can be placed anywhere, with a growth direction and frame width, or switched to List mode: one buff per line, longest at the top, with its name and time beside the icon
- Weapon enchants, such as poisons and oils, show at the start of the long buffs
- Short buffs sit above the player bar, as wide as it and clear of your name, filling right towards the orb, then up
- Hover a buff for its tooltip, and right-click it out of combat to cancel it
- Icons can be skinned with Masque

**Opacity**

Pick a mode in the settings. Smart, the default, follows what's happening:

| State | Smart | Minimalist |
|---|---|---|
| In combat | 100% | 100% |
| Out of combat, targeting an attackable unit | 60% | 60% |
| Out of combat, with health below full, or power away from its idle level | 60% | 60% |
| Otherwise, out of combat | 30% | Hidden |

**Full** is always 100%, and **Manual** is always the opacity you set. Rage idles at 0, and other power types idle at full. Casts always show at 100%, whatever the mode.

**Last names**
- Can be switched on in the settings, to show "First Last" on the player, target and target of target
- The last name is off-white and 20% smaller than the first, and the player's level follows it

**Clicks**
- Left-click a bar to target that unit, and right-click for its menu

**Minimap button**
- Click it to open or close the settings, and drag it to move it around the minimap's edge
- Can be hidden in the settings

## Installation

Copy the `DibsUI` folder into your game's `_forever_/Interface/AddOns/` folder, then restart the game or type `/reload`.

The other files in this repository aren't needed in-game.

## Settings

Type `/dui` or `/dibsui`, or click the minimap button, to open the settings window. It's built from Blizzard's newer panels, switches, sliders and dropdowns, and has four tabs.

At the top of the window, on every tab:

| Setting | What it does |
|---|---|
| Unlock frames | Shows drag handles for the frames and the long buffs. Bars don't respond to clicks until you switch it off again. |
| Show minimap button | Turns the minimap button on or off. |

### Look and feel

**Frames**

| Setting | What it does |
|---|---|
| Show target of target | Turns the target of target bar on or off. |
| Scale | Scales everything from 0.50 to 2.00. Use the slider or its arrows, or type an exact value and press Enter. |
| Width | Sets the length of the player and target bars from 0.50 to 2.00. Use the slider or its arrows, or type an exact value and press Enter. |
| Pet and target of target width | Sets the length of both of those bars from 0.50 to 2.00. Use the slider or its arrows, or type an exact value and press Enter. |
| Show last names | Shows last names beside first names, smaller and off-white. |

**Position**

| Setting | What it does |
|---|---|
| Center horizontally | Centers the orb on the screen, keeping its height. The pet bar doesn't change where the center is. |
| Up, Down, Left, Right | Moves the frames one screen pixel. These and Center work whether or not the position is locked. |

**Opacity**

| Setting | What it does |
|---|---|
| Mode | Smart, Minimalist, Full or Manual, as described above. |
| Manual opacity | The opacity Manual holds, from 0% to 100%. |

Unlocked frames always show at 100%, so you can see them to move them.

### Text options

Pick a spot from **Text to edit**. Spots are named by where they sit, such as "Player bar: Left side" or "Orb: Center", then change it:

| Setting | What it does |
|---|---|
| Show | Turns the spot on or off. |
| Only on mouseover | Shows the spot only while your mouse is over its bar, or over the orb for the orb and cast text. |
| Shows | What a health or power spot displays. Names, levels and cast text always show the same thing. |
| Font | The game's fonts, plus any fonts from addons that use LibSharedMedia. Each one is shown in its own typeface. |
| Size | From 6 to 40. |
| X offset, Y offset | Moves the spot from where it normally sits, from -100 to 100. Positive Y is up. |
| Custom color | Switch it on and click the swatch to pick a color. Switched off, the spot keeps its usual color, such as a class or difficulty color. In name and level spots, the level stays yellow. |
| Reset this text | Puts everything about the spot back to its defaults. |
| Use font for all text | Gives every spot the font of the one you've picked, leaving everything else alone. |

A health or power spot can show:

| Option | Example |
|---|---|
| Current | `13k` |
| Current / max | `13k / 18k` |
| Percent | `70%` |
| Missing | `5k`, hidden when full |
| Percent and current | `70% - 13k`, with the percent larger |

The defaults are the layout above: missing health on the player bar's left side, percent and current on the target's, and the pet's current / max on mouseover.

### Buffs/Debuffs

The groups are listed down the left, each with its own switch. Click one to change its settings. Player debuffs, target buffs and target debuffs are coming later.

**Show test buffs** fills every group with sample buffs, so you can see the layout as you change it. It turns off when you reload.

**Player long buffs**

| Setting | What it does |
|---|---|
| Mode | Standard, a grid of icons with the time under each, or List, one buff per line. Each mode keeps its own settings and position. |
| Icon size, Spacing | In both modes. Spacing applies between icons and between lines. |
| Growth | Standard: which way icons fill a line, then which way new lines go. The first buff sits in the corner both start from. |
| Frame width | Standard: how long a line is, in UI units. The number of buffs per line follows from the icon size and spacing. For growth that fills up or down first, this is the frame's height. |
| Time text | Standard: font, size and color. |
| Icon on the right | List: puts the icons down the right side, with the text on their left. |
| Name, Time | List: font, size and color of each. The name lines up with the icon's top and the time with its bottom. |
| Frame point, Attach to, Attach point, X offset, Y offset | Where the frame sits: a point of the frame, attached to a point of the screen, the DibsUI frames, the orb or the minimap. You can also drag it while frames are unlocked. |

**Player short buffs**

| Setting | What it does |
|---|---|
| Icon size, Spacing | Size of the icons and the gap between them and between lines. |
| Time text | Font, size and color. |

Sizes and offsets follow your UI scale. The short buffs also follow DibsUI's Scale setting, since they sit on the player bar.

### Profiles

Profiles are shared by every character on your account, and each character remembers which one it uses. Your settings start in the **Default** profile, and new characters use it too.

- **Current profile** shows the one this character uses.
- Click a profile in the list to use it.
- **New profile** asks for a name and a profile to copy from, or starts from the default settings. The new profile is used straight away.
- The red X deletes a profile, after you confirm. Default and the profile in use can't be deleted, and characters that used a deleted profile go back to Default.

The minimap button's settings are the same in every profile.

Frame, position and profile settings can't be changed during combat, but text, last name, opacity, buff and minimap settings can. Changes to buff icons, fonts and colors made during combat show once it ends.

## Status

Early development, for interface version 16001.

So far DibsUI has been tested in the UIForever simulator and with offline checks, not in the live game. Behavior that depends on the real client, such as secret health and power values in combat, real swing timer events, a real pet, real combo points, real spell costs, how the settings window looks in the live game, and profiles across real characters, still needs checking in-game.

The buff frames are newer still: the simulator can't show real buffs in Blizzard's aura container, the offline checks don't cover them yet, and real buffs, sorting in combat, cancelling, tooltips and Masque skins on them haven't been checked in-game.

## Known limitations

- Hiding Blizzard's target frame also hides your target's buffs and debuffs
- Totem and class resource bars still sit where Blizzard's player frame was
- In a vehicle, the bars keep showing your character
- Only the main frames are kept on screen when dragging, so the pet and target of target bars can go past the screen's edges
- The target of target bar still shows when you target yourself
- The mana spark won't start for a spell whose cost is a secret value, and may start for a free cast from a proc like Clearcasting
- Names are cut short to fit their bar, so a larger font size or a last name shows less of a long name
- When the game hides a name's details, such as in some instances, the name shows without its last name
- At 0% opacity the bars are invisible but can still be clicked
- Fills start outside the orb's ring, so a nearly empty health bar looks slightly fuller than it is
- If health and power are both secret values out of combat, only health can affect opacity
- A long buff that's neither in the client's spell list nor seen before shows with the short buffs until the fight ends. The list is taken from build 1.60.1.70790 and needs regenerating for new builds
- Weapon enchants only show in the long buffs, so with long buffs off and short buffs on they aren't shown anywhere
- In List mode, a weapon enchant shows the weapon's name
- In List mode, names longer than the space beside the icons run past the frame
- The long buffs' drag handle is sized from the buffs you had the last time they could be read

## License

[MIT](LICENSE)
