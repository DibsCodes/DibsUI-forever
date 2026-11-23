# Changelog

## 0.3.7

- New focus frame, styled like a DibsUI-Party member: your focus's portrait in an orb, a tall health bar and a power bar. Drag it while DibsUI is unlocked. With no focus it shows you as a stand-in so you can place it. It has its own Focus Frame page in the settings with width, scale and its texts
- The ring round the focus's portrait is its cast bar: gold for casts, teal for channels, grey when the cast can't be interrupted. The spell's icon shows in the portrait, with its name and time under the orb
- When your focus is interrupted it says "Interrupted", with the name of whoever did it in their class colour
- The focus frame fades while your focus is out of range. Turn it off with Fade when out of range
- Focus buffs and debuffs, set up like the target's on the Buffs & Debuffs page. Buffs can attach to the new "DibsUI focus frame" point
- Turn the whole focus frame off with Show DibsUI focus frame to use Blizzard's focus frame instead

## 0.3.6

- Bronze theme: the health, power and pet bar borders are redrawn at the tips, so the bar's fill no longer shows through the border at full health
- Bronze theme: the health and power borders no longer jump from bright to dark partway along, and the dark patch under the eagle's wing is gone

## 0.3.5

- New Theme setting on the General page: Default (brushed silver and gold) or Bronze (rough cast bronze with a carved eagle, and a slightly bigger orb rim). Each profile keeps its own theme, and it switches straight away, in combat too
- With DibsUI-Party installed, changing the theme in either addon asks whether to use it for the other one too

## 0.3.4

- The cast ring is animated: light flows round it while you cast, and slides back when a hit pushes your cast back. The swing timer flows the same way. Turn it off with Animated ring on the Cast Ring page
- A green ring for the global cooldown after an instant ability, with the spell's name and icon. Casts come first, then the global cooldown, then the swing timer. Turn it off with Show global cooldown
- A faint red glow round the orb and your bars when your health is low. Turn it on or off and set when it shows (20% by default) under Low health on the General page
- A new orb style, Flat
- Power Orb and Cast Ring have their own pages in the settings. On every page the text settings come after the other switches, and a text's settings are grouped under it
- The default font is now Barlow Semi Condensed Bold. Black is still in the font list
- The name above the target bar shows in full at once, like the player's since 0.3.3

## 0.3.3

- First full release, no longer a beta. DibsUI-Options is a full release too, so the CurseForge app can install it along with DibsUI
- With last names on, your name above the player bar shows at login without toggling a setting

## 0.3.2

- No changes in the game. Brings 0.3.1 to CurseForge as a beta, since it only came out as an alpha

## 0.3.1

- DibsUI-Party's frames follow DibsUI's master font and last names, and change straight away when you change them here. Needs DibsUI-Options 0.2.0

## 0.3.0

- DibsUI now needs [DibsUI-Options](https://www.curseforge.com/projects/1808425), which the CurseForge app installs along with it. The settings window, profiles, minimap button and `/dibsui` moved there, so every DibsUI addon can share them
- Your profiles, each character's choice of profile and the minimap button's settings move over the first time both load. Nothing else changes: the window, its pages and your settings look the same as before

## 0.2.0

- A rebuilt settings window, with DibsUI's logo at the top left and its pages listed down the left: General, Player & Pet Frame, Target Frame, Power Orb and Cast Ring, Buffs & Debuffs, Incoming Combat Text and Profiles. Each frame's page has its own text settings, so the Text tab is gone
- DibsUI is now listed in the game's Options under AddOns, with a button that opens its settings
- The player and target bars can have different widths, and so can the pet and target of target bars. Each pair is linked by default; changing one bar on its own page unlinks it, and the chain beside the width links them again. Your current widths carry over, still linked
- A master font, which every text uses unless it has its own, with a button to use it for all text, buffs and combat text included. DibsUI now comes with Barlow Semi Condensed Black, and uses it by default
- Every text can now have its own outline: none, outline or thick outline
- New switches: Show pet frame, Show five second rule timer, Show swing timer, and the spell icon beside the cast name. The orb's liquid can be Animated or Plain
- The Unlock frames switch is now a button that says Lock frames while they're unlocked
- Buff group settings are in the order Layout, Position, Icons, then the texts
- The minimap button shows DibsUI's logo
- Fixed buttons in the settings window losing their text while the mouse is over them

## 0.1.6

- Fixed incoming heals and absorbs not showing on the player and target bars in game since 0.1.2. The masks that hide the empty pieces' slanted ends were hiding the heals and absorbs entirely. They now work like the orb's masks, so heals and absorbs show and the bar's end still matches the fill below 100% opacity

## 0.1.5

- Fixed a Lua error in combat ("attempt to perform arithmetic on a secret number value" in CombatText.lua). Damage amounts are secret in combat, which made the combat text lines' positions secret too, so they're now moved without reading them

## 0.1.4

- The game's scrolling combat text now rises from just above the player bar, or above your short buffs while you have any, instead of up the middle of the screen. A burst of hits stacks upwards without covering the bar
- A new Combat text tab: switch the move on or off, attach it to the player bar or drag it anywhere while frames are unlocked, nudge it with offsets, and pick its font, outline and scale
- Custom colors for melee hits, spell hits, heals, and misses, blocks and resists
- None of this taints Blizzard's combat text, which handles amounts addons can't read

## 0.1.3

- Druids in bear or cat form see their mana percentage under the rage or energy in the orb, in smaller blue text. It's in the Text tab as "Orb: Druid mana", where it can be turned off, shown only on mouseover, set to show other values, moved and restyled

## 0.1.2

- An animated Zzz at the top left of the player bar while you're resting
- A PvP icon under the player bar's outer corner while you're flagged, in your faction's colors (or free for all), with the time left before the flag drops. Its time can be moved and restyled in the Text tab as "Player bar: PvP timer"
- New switches in General: Show incoming heals and absorbs, and Show PvP icon and timer
- The cast's spell name and time can go above the orb instead of below it (General, Cast)
- The cast text spots in the Text tab are now called Cast: Spell name and Cast: Time, instead of Top line and Bottom line
- Fixed the slanted end of the player and target health bars looking too solid below 100% opacity. The empty heal and absorb pieces sat under it and showed through

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
