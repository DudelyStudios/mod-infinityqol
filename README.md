# Infinity QoL

A Wrath 3.3.5 quality-of-life module for WoWUnbound (AzerothCore). Stack sizes are applied by this module when the world server starts. The pet rules live in the WoWUnbound core and read this module's config.

## Install

In Yu'lon, on the Modules tab, choose **Install a module from a link** and paste:

https://github.com/DudelyStudios/mod-infinityqol

Yu'lon clones that repository into `modules/mod-infinityqol`. The folder ships `src/`, an empty `include.sh`, and `conf/mod_infinityqol.conf.dist`. There is no SQL. Rebuild the world server after the install. The module does nothing until that rebuild.

Release `v1.0.0` is the first installable version. Later commits on `main` are what Yu'lon's update check counts.

The client addon is attached to the release as `InfinityQoL-client.zip`, and it is also in `client/InfinityQoL`. Unzip it into each member's `Interface/AddOns` folder so the result is `Interface/AddOns/InfinityQoL`, then `/reload`. Yu'lon's module install leaves the game client alone.

## Configuration

`InfinityQoL.Enable = 0` turns every feature off.

`InfinityQoL.Pets.Enable` lets a hunter keep a beast out beside a demon, ghoul, or water elemental. The beast keeps the pet bar. Attack, follow, stay, and aggression on that bar reach every pet. Tame Beast ignores the class pet and still refuses a new beast while the active hunter pet is unstabled. `InfinityQoL.Pets.StableSlots` grants that many stable slots to hunters, from 1 to 20. The addon draws slots 5–20 beside the stable window. A character already in the world sees a new slot count after relog. `InfinityQoL.Pets.SpellBar` keeps stance and aggression on the normal pet bar and lists every controlled pet's abilities on one extra bar. A left click casts. A right click toggles autocast when the spell allows it.

`InfinityQoL.Stack.Enable` raises the stack size of consumables and trade goods that already stack. `InfinityQoL.Stack.Consumable` and `InfinityQoL.Stack.TradeGoods` are the caps. `0` leaves that class at the database value. Items that stack to 1 stay at 1. Quest items, gems, glyphs, and grey junk are left alone. The highest accepted value is 100000. Players already in the world see a new cap after relog.

`InfinityQoL.Spellbook.Enable` tells the Unbound spellbook which spells this character has learned. The class tab shows the highest learned rank in color, and dims a catalog spell the character has not learned. The marks are drawn by the Unbound spellbook addon, which ships with the client.

## Startup

On worldserver startup the module logs whether it loaded, whether pets are on, which stack caps it applied, and whether the spellbook list is on.
