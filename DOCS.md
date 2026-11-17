# rsg-weaponcomp – Technical Docs (v3.5.0)

Weapon customisation for RSG Framework (RedM). Players place a portable gunsmith workbench, then use it to change parts, materials, engravings, tints and wraps on the weapon in their hands, with a live 3D preview. This document covers the architecture, data formats, every event, callback and command, configuration, security model and how to extend the script.

## Contents
1. [Overview and dependencies](#1-overview-and-dependencies)
2. [Files](#2-files)
3. [How it works](#3-how-it-works)
4. [Configuration](#4-configuration)
5. [Data formats](#5-data-formats)
6. [Events, callbacks, commands and items](#6-events-callbacks-commands-and-items)
7. [Exports and helper APIs](#7-exports-and-helper-apis)
8. [Integration examples](#8-integration-examples)
9. [Persistence and database](#9-persistence-and-database)
10. [Security model](#10-security-model)
11. [Discord logging](#11-discord-logging)
12. [Locales](#12-locales)
13. [Server owner how-tos](#13-server-owner-how-tos)
14. [Troubleshooting](#14-troubleshooting)

---

## 1. Overview and dependencies

| Dependency | Used for |
|---|---|
| `rsg-core` | Player data, callbacks, notify, progress bar, DrawText, locales, commands, usable items |
| `rsg-inventory` | Weapon items (`info` data), `CanAddItem`, item box |
| `rsg-weapons` | `weaponInHands()` export (weapon hash → serial) |
| `rsg-target` | Target option on placed workbenches |
| `rsg-gizmo` | Workbench placement (`Place`, `Cancel`, `IsPlacementValid`) |
| `oxmysql` | `player_weapons` and `player_weapons_custom` tables |

There is no ox_lib or ox_target dependency. Optional: `rsg-log` (mirror of the Discord logs).

---

## 2. Files

| File | Side | Purpose |
|---|---|---|
| `fxmanifest.lua` | – | Manifest; shared scripts, NUI page, dependencies |
| `shared/config.lua` | shared | Workbench, items, camera, commands, prices, restrictions, all component lists, damage modifiers |
| `shared/utils.lua` | shared | `WeaponComp` helpers: factory categories, apply order, price calculation |
| `client/client.lua` | client | Workbench props and targets, customisation flow, orbit camera, NUI callbacks, setup / pack-up |
| `client/inhands.lua` | client | Re-applies saved components when a weapon is drawn, scope commands |
| `client/inspect.lua` | client | Native weapon inspection, cleaning with a repair kit |
| `client/maintenance.lua` | client | Gun oil (`Maintenance` helpers and the `oilWeapon` event) |
| `client/propplace.lua` | client | Workbench placement through rsg-gizmo |
| `client/dataview.lua` | client | Buffer helper used for weapon stats natives |
| `server/database.lua` | server | `EnsureDatabase()`: creates the tables and adds missing columns on start |
| `server/server.lua` | server | Purchases, reset, whitelist, workbench persistence and access, admin commands, discount / skill / materials, presets, identity, repair, gun oil |
| `server/config.lua` | server | Discord webhooks (never sent to clients) |
| `server/discord.lua` | server | `Discord.Log`, `Discord.Security`, `Discord.FormatComponents` |
| `server/versionchecker.lua` | server | GitHub version check |
| `html/index.html`, `script.js`, `style.css` | NUI | Customisation menu |
| `installation/database.sql` | – | Database schema (manual install; identical to what `database.lua` creates) |
| `locales/*.json` | shared | `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro` |

Load order (from `fxmanifest.lua`): `shared/config.lua` → `shared/utils.lua` → `client/*.lua`; on the server `server/config.lua` → `server/discord.lua` → `server/database.lua` → `server/server.lua` → `server/versionchecker.lua`.

---

## 3. How it works

### 3.1 Placing a workbench
1. The player uses the `gunsmith` item. The server (`CreateUseableItem`) checks `Config.RequiredJob` and sends `rsg-weaponcomp:client:createprop` with `{ propmodel, item }`.
2. `client/propplace.lua` calls **rsg-gizmo**:
   ```lua
   local res = exports['rsg-gizmo']:Place(propmodel, {
       rotation = 'z',
       maxDistance = Config.PlaceDistance or 5.0,
   })
   if not res then return end -- cancelled or invalid
   TriggerEvent('rsg-weaponcomp:client:setupgunzone', res.coords, res.heading or res.rotation.z)
   ```
   `Place` blocks until the player confirms or cancels, so it runs in its own thread.
3. `setupgunzone` (client) checks range, overlap with other workbenches (`Config.gunZoneSize`) and the player's workbench count (`rsg-weaponcomp:server:countprop`), then plays a cancellable progress bar (`Config.SetupTime`).
4. When the bar completes the client sends `rsg-weaponcomp:server:createnewprop(coords, heading)`. The server re-validates everything (section 10), takes the item, inserts the row and syncs `Config.PlayerProps` to every client.
5. Clients spawn the prop when within the render distance and attach an rsg-target option to it.

### 3.2 Customising a weapon
1. The player holds a weapon and targets the workbench → **Use Gunsmith** (`onUseGunsmith`). The weapon must have a serial from `rsg-weapons` (bows and melee use the weapon hash as serial) and must not be in `Config.WeaponRestriction`.
2. `startCustomisation` freezes and hides the ped, creates a weapon object on the workbench, starts the orbit camera and the camera prompts, and fetches the saved components with `rsg-weaponcomp:server:getPlayerWeaponComponents`.
3. `GetAvailableComponents(weaponName, wHash)` merges the weapon's `Config.Specific` lists with its weapon-type `Config.Shared` lists (specific wins; shared categories are filtered by `Config.SharedRequires`). `FRAME_VERTDATA` is always excluded from the menu.
4. The NUI receives an ordered category array (`action = 'open'`). Each pick sends the `componentChanged` NUI callback; the client applies it to the preview object and returns the new price (`updatePrice`).
5. **Purchase** sends `rsg-weaponcomp:server:purchase(serial, wHash, weaponName, comps)`. **Reset** sends `rsg-weaponcomp:server:reset`. The server whitelists the components, works out the price itself, charges and saves.
6. When the weapon is drawn later, `client/inhands.lua` re-applies the saved components (section 3.3).

### 3.3 Re-applying components
`inhands.lua` polls the held weapon every 500 ms. When it changes (or on `/loadweapon`) it triggers `rsg-weaponcomp:client:reloadWeapon`, which:
1. fetches the saved components,
2. removes every available component from the ped's weapon,
3. builds the loadout: saved parts plus the **factory part** (first list entry) for every structural slot (`BARREL`, `GRIP`, `SIGHT`, `CLIP`, `TUBE`, `MAG`, `STOCK`) that was not modified,
4. applies the loadout in `WeaponComp.Priority` order, then re-applies finishes three more times because they sometimes do not stick on the first pass.

### 3.4 Pricing
`WeaponComp.ChangePrice(current, new)` (shared, so the NUI total and the server charge always agree):
- a new or changed category costs `Config.price[category]`,
- removing a category back to factory costs `Config.price[category] * Config.RemovePrice`,
- the total is rounded to cents,
- the server charges from `Config.PaymentType` using `RemoveMoney`.

Factory structural parts (`WeaponComp.FactoryCategories`) are never stored and never charged.

### 3.5 Maintenance
- **Repair kit** (`Config.RepairItem`): `rsg-weaponcomp:server:useRepairKit` takes one kit and sets `item.info.quality = 100`. It refuses when the weapon is already at 100.
- **Gun oil** (`Config.GunOilItem`): `rsg-weaponcomp:server:useGunOil` takes one oil; the client then clears dirt and soot (visual only, no condition change).
- Both are available at the workbench (menu) and via the inspect command / gun oil item.

---

## 4. Configuration

### 4.1 `shared/config.lua`

| Option | Default | Description |
|---|---|---|
| `PlayerProps` | `{}` | Runtime list of placed workbenches (filled from the database, do not edit) |
| `PlaceDistance` | `5.0` | Maximum placement range from the player (gizmo `maxDistance` and server check) |
| `UseDistance` | `6.0` | Server-checked distance to a workbench for purchase / reset |
| `SetupTime` | `10000` | ms of the cancellable set-up bar after placing |
| `RepairItem` | `'weapon_repair_kit'` | Repair kit item |
| `GunOilItem` | `'weapon_gun_oil'` | Gun oil item; `nil` disables gun oil |
| `GunOilTime` | `6000` | ms of the oiling animation |
| `Gunsmithitem` | `'gunsmith'` | Workbench item |
| `RequiredJob` | `nil` | Job name required to place a workbench (`nil` = anyone) |
| `Gunsmithprop` | `` `p_gunsmithprops09x` `` | Workbench model (hash) |
| `MaxGunsites` | `6` | Workbenches per player |
| `PaymentType` | `'cash'` | Account charged (`cash`, `bank`, ...) |
| `animationSave` | `10000` | Save animation time (ms) |
| `AutoDatabase` | `true` | Create / upgrade the tables on start (`false` = import `installation/database.sql` yourself) |
| `AllowPushToTalkWhileOpen` | `true` | Keep push-to-talk usable while the menu has focus |
| `PushToTalkControls` | `{ 0x4BC9DABB }` | Controls re-enabled while the menu is open |
| `DefaultAccess` | `'everyone'` | Who may use a new player workbench: `everyone`, `owner`, `job`, `gang` |
| `WorkbenchExpireDays` | `0` | Remove player workbenches unused for this many days (`0` = never; public benches never expire) |
| `AdminPermission` | `'admin'` | Permission for the admin commands (`RSGCore.Functions.HasPermission`) |
| `CommandAdminPlace` / `CommandAdminList` / `CommandAdminRemove` | `createworkbench` / `listworkbenches` / `removeworkbench` | Admin command names |
| `GunsmithJobs` | `{ gunsmith = { discount = 0.25, requireDuty = true } }` | Discount on every purchase, reset and identity change for holders of the job (capped at 90%) |
| `Skill` | table, `Enabled = false` | `MetaKey` (player metadata), `XPPerPurchase`, `XPJobBonus`, `Levels` (XP for level 1..n), `Unlocks` (category → minimum level) |
| `PartItems` | `{}` | `{ CATEGORY = { { item = 'steel', amount = 1 } } }`: items taken for each part bought in that category |
| `MaxPresets` | `5` | Saved loadouts per player and weapon |
| `Identity` | table | `Enabled`, `NamePrice`, `EngravePrice`, `MaxNameLength` (24), `MaxEngravingLength` (40) |
| `gunZoneActive` | `false` | Enable the workbench name text when standing near one |
| `gunZoneSize` | `3.0` | Minimum distance between workbenches and the text zone radius |
| `showTextZone` | `false` | Show the workbench name with `DrawText` (needs `gunZoneActive`) |
| `distBack` | `0.7` | Camera distance as a multiple of the weapon length |
| `distFov` | `60.0` | Camera field of view |
| `showStats` | `true` | Show the native weapon stats during inspection |
| `Commandinspect` | `'w_inspect'` | Inspect / clean command |
| `Commandloadweapon` | `'loadweapon'` | Re-apply components command |
| `Commandequipscope` | `'scope'` | Equip scope command |
| `Commanddesequipscope` | `'unscope'` | Remove scope command |
| `prompts` | table | Camera controls: `zoIn`, `zoOut`, `ranPos`, `re`, `rotLeft`, `rotRight` (control hashes) |
| `camRotateSpeed` | `90.0` | Orbit speed in degrees per second |
| `AutoFocusDefault` | `true` | Default for the in-menu auto part focus (players can toggle it) |
| `PartFocus` | table | Per-category camera focus: `at` (0.0 stock end to 1.0 muzzle) and `zoom` |
| `WeaponRestriction` | list | Weapon names that cannot be customised |
| `RemovePrice` | `0.3` | Fraction of the price charged to remove a modification |
| `price` | table | Price per category (see below) |
| `SharedRequires` | table | Rules for when weapon-type categories are offered |
| `Shared` | table | Component lists per weapon type: `SHORTARM`, `LONGARM`, `SHOTGUN`, `MELEE_BLADE` |
| `Specific` | table | Component lists per weapon name |

### 4.2 `server/config.lua`
Discord settings only (`DiscordConfig`); see [section 11](#11-discord-logging). Never add this file to `shared_scripts`; it holds the webhook URLs.

### 4.3 Price table
`Config.price` is keyed by category. Missing keys count as `0.0` (free).
```lua
Config.price = {
    ["BARREL"] = 1.00,
    ["SCOPE"] = 2.00,
    ["WRAP_TINT"] = 0.50,
    ["FRAME_ENGRAVING"] = 1.50,
    -- ...
}
```
A weapon that changes `BARREL` (1.00) and `WRAP_TINT` (0.50) and removes `SCOPE` (2.00) costs `1.00 + 0.50 + 2.00 * 0.3 = 2.10`.

### 4.4 Specific and shared component lists
```lua
-- Weapon-specific: the first entry of a structural category is the factory part
Config.Specific["WEAPON_REVOLVER_CATTLEMAN"] = {
    ["BARREL"] = {
        "COMPONENT_REVOLVER_CATTLEMAN_BARREL_SHORT",
        "COMPONENT_REVOLVER_CATTLEMAN_BARREL_LONG",
    },
    ["GRIP"] = { "COMPONENT_REVOLVER_CATTLEMAN_GRIP", "COMPONENT_REVOLVER_CATTLEMAN_GRIP_PEARL" },
}

-- Weapon-type shared lists (SHORTARM, LONGARM, SHOTGUN, MELEE_BLADE)
Config.Shared["SHORTARM"]["WRAP_TINT"] = { "COMPONENT_SHORTARM_WRAP_TINT_WHITE", ... }

-- Only offer a shared category when the weapon fits
Config.SharedRequires.CYLINDER_MATERIAL = { weapon = { 'REVOLVER' } }  -- weapon name contains 'REVOLVER'
Config.SharedRequires.WRAP_TINT         = { part = 'WRAP' }            -- weapon must define WRAP in Config.Specific
```
The component lists in `shared/config.lua` use two small helpers so long runs don't have to be typed out:
```lua
seq('COMPONENT_SHORTARM_BARREL_MATERIAL_', 1, 10)   -- 'COMPONENT_SHORTARM_BARREL_MATERIAL_1' ... '_10'
join({ 'COMPONENT_X_WHITE' }, seq('COMPONENT_X_A_', 1, 8))  -- one list, in order
```
Lists used by several weapons (for example `LONGARM_WRAP_TINT`) are defined once as a local above `Config.Shared` and referenced by name. They are shared references: don't modify them at runtime.

Weapon type comes from `GetWeapontypeGroup`: repeater / rifle / sniper → `LONGARM`, shotgun → `SHOTGUN`, pistol / revolver → `SHORTARM`, melee → `MELEE_BLADE`, bow → `GROUP_BOW` (specific lists only).

---

## 5. Data formats

### 5.1 Weapon item data (`item.info`)
Components are stored on the weapon item itself by `rsg-inventory`:

| Field | Type | Meaning |
|---|---|---|
| `serie` | string | Weapon serial (set by rsg-weapons) |
| `componentshash` | `{ [category] = componentName }` | The real modifications, e.g. `{ BARREL = 'COMPONENT_REVOLVER_CATTLEMAN_BARREL_LONG' }`. `nil` when the weapon is at factory |
| `components` | `{ [category] = label }` | Display labels built from the locale of each component |
| `quality` | number 0–100 | Weapon condition (rsg-weapons); a repair kit sets it to 100 |
| `customname` | string | Custom weapon name (identity); `nil` when unset |
| `engraving` | string | Engraving text (identity); `nil` when unset |
| `equippedScope` | boolean | Whether the saved `SCOPE` is currently mounted |

```lua
-- Example componentshash
{
    BARREL = 'COMPONENT_REVOLVER_CATTLEMAN_BARREL_LONG',
    GRIP = 'COMPONENT_REVOLVER_CATTLEMAN_GRIP_PEARL',
    FRAME_ENGRAVING = 'COMPONENT_SHORTARM_FRAME_ENGRAVING_2',
}
```
Rules: keys are category strings, values are component names present in the config whitelist, at most 64 entries. Factory structural parts and `FRAME_VERTDATA` are never stored.

### 5.2 Workbench record (`Config.PlayerProps[i]`, also the `propdata` JSON column)
```lua
{
    gunsitename = 'Gunsmith',     -- localised display name
    gunsiteid   = 'CSID12345678', -- unique id (database primary key)
    propid      = 'PID87654321',  -- unique prop id (used by targets and pack-up)
    item        = 'gunsmith',     -- item returned on pack-up
    x = 0.0, y = 0.0, z = 0.0,    -- position
    h = 0.0,                      -- heading
    propmodel   = 1234567890,     -- model hash
    citizenid   = 'ABC12345',     -- owner
    buildttime  = 1700000000,     -- os.time() when placed
    lastused    = 1700000000,     -- last time someone used it (saved at most every 10 minutes)
    access      = { type = 'everyone' }, -- 'everyone' | 'owner' | 'job' | 'gang' (+ value = job / gang name)
    public      = true,           -- only on admin benches (citizenid = 'public'): usable by all, never expire, not counted in MaxGunsites
}
```

### 5.3 Component priority (`WeaponComp.Priority`)
Components are applied in this order so tints and materials are not dropped by the game:

| Priority | Category |
|---|---|
| 1–9 | `BARREL`, `GRIP`, `STOCK`, `SIGHT`, `SCOPE`, `CLIP`, `MAG`, `TUBE` |
| 20 | `*RIFLING` |
| 30 / 40 / 45 | `*_MATERIAL` / `*_ENGRAVING` / `*_ENGRAVING_MATERIAL` |
| 50 | `*_TINT` |
| 60 / 65 / 70 | `WRAP` / `WRAP_MATERIAL` / `WRAP_TINT` |
| 35 | everything else |

### 5.4 NUI messages
Client → NUI (`SendNUIMessage`):

| `action` | Payload |
|---|---|
| `open` | `weaponName`, `serial`, `components` (ordered array of `{ category, label, items = { { name, hash, label } } }`), `prices`, `savedComponents`, `autoFocus`, `condition`, `features` (`discount`, `skill`, `locked`, `materials`, `identity`, `maxPresets`, `access`), `locales` |
| `close` | – |
| `updatePrice` | `price` (after discount), `base`, `discount`, `changed`, `balance`, `canAfford` (false turns the total red), `materials` (`{ label, amount, have }[]`), `missing`, `canUndo`, `canRedo`, `comparing` |
| `selection` | `selected` (`{ category = component }`): move every slider after undo / redo / compare / preset |
| `presets` | `list` (`{ id, name, components }[]`) |
| `identity` | `identity` (`{ name, engraving }`) after a successful save |
| `access` | `access` (`{ canManage, mode }`) when the bench record changes |
| `updateCondition` | `condition` (quality, cleanliness, item counts) |
| `notify` | notification text (handled in the NUI) |

NUI → client (`RegisterNUICallback`): `closeUI`, `setAutoFocus`, `notify`, `componentChanged { category, component }`, `undo`, `redo`, `compare { on }`, `revert`, `purchase`, `resetWeapon`, `maintain { kind = 'oil' | 'repair' }`, `packup`, `listPresets`, `savePreset { name }`, `deletePreset { id }`, `loadPreset { id }`, `saveIdentity { name, engraving }`, `setAccess { mode }`, `inputFocus { focused }` (the menu tells the game when a text box has focus so typed letters don't move the camera).

**Push-to-talk:** all NUI focus changes go through `applyNuiFocus`. While the menu is open the per-frame control block disables every control on groups 0, 1 and 2, then re-enables the camera keys and, when `Config.AllowPushToTalkWhileOpen` is true, the controls in `Config.PushToTalkControls`. While a text box has focus, `SetNuiFocusKeepInput(false)` is used so the keys go to the box.

---

## 6. Events, callbacks, commands and items

### 6.1 Server events (client → server)
All have a per-player cooldown and validate their arguments.

| Event | Arguments | Cooldown | Purpose |
|---|---|---|---|
| `rsg-weaponcomp:server:purchase` | `serial, wHash, weaponName, comps` | 3 s | Buy the selected component set |
| `rsg-weaponcomp:server:reset` | `serial, wHash, weaponName` | 3 s (shared with purchase) | Strip back to factory (pays `RemovePrice`) |
| `rsg-weaponcomp:server:createnewprop` | `coords (vector3), heading (number)` | 5 s | Create a workbench after placement |
| `rsg-weaponcomp:server:removegunsiteprops` | `propid (string)` | 3 s | Pack up a workbench (owner only) |
| `rsg-weaponcomp:server:setaccess` | `propid, mode` | 1 s | Owner changes who can use the bench (`everyone`, `owner`, `job`, `gang`; job / gang use the owner's current one) |
| `rsg-weaponcomp:server:adminplace` | `coords, heading` | 2 s | Create a public workbench (requires `Config.AdminPermission`) |

### 6.2 Server callbacks (`RSGCore.Functions.TriggerCallback` / `AwaitCallback`)

| Callback | Arguments | Returns |
|---|---|---|
| `rsg-weaponcomp:server:getPlayerWeaponComponents` | `serial, weaponName` | `{ components?, quality, discount, level?, xp?, identity = { name, engraving } }` or `nil` |
| `rsg-weaponcomp:server:setIdentity` | `serial, weaponName, name, engraving` | `ok, identity` (needs a usable bench; charges `NamePrice` / `EngravePrice` only for non-empty new text; clearing is free) |
| `rsg-weaponcomp:server:listPresets` | `weaponName` | `{ id, name, components }[]` |
| `rsg-weaponcomp:server:savePreset` | `weaponName, name, comps` | `boolean` (components validated for that weapon, max `MaxPresets`) |
| `rsg-weaponcomp:server:deletePreset` | `id` | `boolean` (own presets only) |
| `rsg-weaponcomp:server:equipScope` | `serial` | `boolean` |
| `rsg-weaponcomp:server:unequipScope` | `serial` | `boolean` |
| `rsg-weaponcomp:server:getProps` | – | `Config.PlayerProps` |
| `rsg-weaponcomp:server:countprop` | – | Number of workbenches the caller owns |
| `rsg-weaponcomp:server:useRepairKit` | `serial` | `boolean` (kit taken, quality set to 100; 8 s cooldown) |
| `rsg-weaponcomp:server:useGunOil` | `serial` | `boolean` (oil taken; 5 s cooldown) |

### 6.3 Client events

| Event | Arguments | Purpose |
|---|---|---|
| `rsg-weaponcomp:client:createprop` | `{ propmodel, item }` | Start workbench placement with rsg-gizmo |
| `rsg-weaponcomp:client:setupgunzone` | `coords, heading` | Validate and run the set-up bar, then ask the server to create the workbench |
| `rsg-weaponcomp:client:confirmpackup` | `propid` | Pack-up progress bar, then asks the server to remove the workbench |
| `rsg-weaponcomp:client:updatePropData` | `props` | Server → client sync of `Config.PlayerProps` |
| `rsg-weaponcomp:client:adminplace` | – | Start gizmo placement of a public workbench (sent by `/createworkbench`) |
| `rsg-weaponcomp:client:printlist` | `lines` | Print the workbench list to the F8 console (sent by `/listworkbenches`) |
| `rsg-weaponcomp:client:animationSaved` | `wHash` | Plays the save animation and reloads the weapon |
| `rsg-weaponcomp:client:reloadWeapon` | `force?` | Re-apply saved components (`force = true` re-applies even when nothing is saved) |
| `rsg-weaponcomp:client:InspectionWeapon` | – | Start the native inspection (cleaning with a repair kit) |
| `rsg-weaponcomp:client:oilWeapon` | – | Start the gun oil clean |
| `rsg-weaponcomp:client:ExitCam` | – | Leave the customisation camera |

### 6.4 Commands
Names come from the `Config.Command*` options. The first four (and the scope commands) are available to every player; the three workbench commands need `Config.AdminPermission`.

| Command | Registered with | What it does |
|---|---|---|
| `/w_inspect` | `RSGCore.Commands.Add` | Inspect the held weapon; clean it with a repair kit |
| `/loadweapon` | `RSGCore.Commands.Add` | Re-apply the saved components to the held weapon |
| `/createworkbench` | `RSGCore.Commands.Add` (`AdminPermission`) | Place a public workbench with rsg-gizmo |
| `/listworkbenches` | `RSGCore.Commands.Add` (`AdminPermission`) | List every workbench (id, owner, position, access) to F8, or the server console when run there |
| `/removeworkbench [id]` | `RSGCore.Commands.Add` (`AdminPermission`) | Remove a workbench by `gunsiteid`, or the nearest one within 5 m. The item is not returned |
| `/scope` | `RegisterCommand` (client) | Mount the saved scope |
| `/unscope` | `RegisterCommand` (client) | Remove the mounted scope |

### 6.5 Items
Add these to `rsg-core/shared/items.lua` (or change the config names):

| Item | Config | Use |
|---|---|---|
| `gunsmith` | `Gunsmithitem` | Usable; places a workbench; returned on pack-up |
| `weapon_repair_kit` | `RepairItem` | Consumed when cleaning / repairing a weapon below 100% |
| `weapon_gun_oil` | `GunOilItem` | Usable; consumed by a quick clean |

```lua
gunsmith        = { name = 'gunsmith',        label = 'Gunsmith Workbench', weight = 5000, type = 'item', image = 'gunsmith.png',        unique = false, useable = true, shouldClose = true, description = 'A portable gunsmith workbench' },
weapon_gun_oil  = { name = 'weapon_gun_oil',  label = 'Gun Oil',            weight = 100,  type = 'item', image = 'weapon_gun_oil.png',  unique = false, useable = true, shouldClose = true, description = 'Cleans dirt and soot off a weapon' },
```

---

## 7. Exports and helper APIs

### Exports

| Export | Side | Signature | Returns |
|---|---|---|---|
| `GetWeaponRecord` | server | `exports['rsg-weaponcomp']:GetWeaponRecord(serial)` | `{ serial, citizenid, components = { [category] = component }, customname, engraving }` from `player_weapons`, or `nil` |

### Events for other resources

`rsg-weaponcomp:server:weaponCustomised` is triggered **on the server** after a purchase, reset or identity change: `(src, serial, itemName, components, identity)` where `identity = { name, engraving }`. Listen with `AddEventHandler` (it is not a net event, so clients cannot fire it):

```lua
AddEventHandler('rsg-weaponcomp:server:weaponCustomised', function(src, serial, itemName, components, identity)
    -- e.g. log it in rsg-lawman's weapon registry
    print(('%s changed %s (%s): %s'):format(src, itemName, serial, identity.name))
end)
```

### Globals inside the resource

It also exposes these globals inside its own resource:

| Global | Side | Signature | Purpose |
|---|---|---|---|
| `WeaponComp.IsFactoryCategory(cat)` | shared | `→ boolean` | True for `BARREL`, `GRIP`, `SIGHT`, `CLIP`, `TUBE`, `MAG`, `STOCK` |
| `WeaponComp.Priority(cat)` | shared | `→ number` | Application order of a category |
| `WeaponComp.SortedKeys(comps)` | shared | `→ string[]` | Category keys in application order |
| `WeaponComp.ChangePrice(current, new)` | shared | `→ price, changed` | Price of going from one component set to another |
| `WeaponComp.SharedCategoryAllowed(cat, weaponName, specific)` | shared | `→ boolean` | Whether a weapon-type category applies to a weapon (`Config.SharedRequires`); used by the menu and the server whitelist |
| `GetWeaponType(hash)` | client | `→ 'SHORTARM' \| 'LONGARM' \| 'SHOTGUN' \| 'MELEE_BLADE' \| 'GROUP_BOW' \| nil` | Weapon-type group |
| `GetWeaponNameFromHash(hash)` | client | `→ string` | Weapon name from hash |
| `GetAvailableComponents(weaponName, wHash)` | client | `→ comps, order` | Merged specific + shared lists |
| `Maintenance.GetDirt(ped)` / `ClearDirt(obj)` / `ClearDegradation(obj)` | client | | Dirt, soot and degradation helpers |
| `Discord.Log(channel, src, title, fields[, description])` | server | | Send a log embed |
| `Discord.Security(src, reason, details)` | server | | Shortcut for the `security` channel |
| `Discord.FormatComponents(comps)` | server | `→ string` | Readable component list |

Other resources reach rsg-weaponcomp through the export and event above, its callbacks, or by reading the weapon item data.

`EnsureDatabase()` (server) creates the tables; it runs automatically when `Config.AutoDatabase` is true.

---

## 8. Integration examples

### 8.1 Read a weapon's modifications from another resource (server)
```lua
local RSGCore = exports['rsg-core']:GetCoreObject()

local function getWeaponComponents(src, serial)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil end
    for _, item in pairs(Player.PlayerData.items) do
        if item.type == 'weapon' and item.info and tostring(item.info.serie) == tostring(serial) then
            return item.info.componentshash -- nil when the weapon is at factory
        end
    end
end
```

### 8.2 Re-apply components after your script changes a weapon (server → client)
```lua
-- force = true also strips parts when nothing is saved (use after clearing componentshash)
TriggerClientEvent('rsg-weaponcomp:client:reloadWeapon', src, true)
```

### 8.3 Open the inspect / clean flow from your own script
```lua
-- client
TriggerEvent('rsg-weaponcomp:client:InspectionWeapon')
-- server
TriggerClientEvent('rsg-weaponcomp:client:InspectionWeapon', src)
```
The player must hold a serialised short or long arm and own a `Config.RepairItem`.

### 8.4 Give a player a workbench item (server)
```lua
local Player = RSGCore.Functions.GetPlayer(src)
if Player and exports['rsg-inventory']:CanAddItem(src, 'gunsmith', 1) then
    Player.Functions.AddItem('gunsmith', 1, nil, nil, 'quest-reward')
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['gunsmith'], 'add', 1)
end
```
The player then uses the item to place it. Placement itself needs the `gunsmith` item in their inventory (the server takes it in `createnewprop`).

### 8.5 Start workbench placement from another script (client)
```lua
-- Opens rsg-gizmo placement; the server still removes the item and validates the result
TriggerEvent('rsg-weaponcomp:client:createprop', {
    propmodel = `p_gunsmithprops09x`, -- model hash of the workbench
})
```

### 8.6 List all placed workbenches (client)
```lua
-- client (the callback is already registered by rsg-weaponcomp)
RSGCore.Functions.TriggerCallback('rsg-weaponcomp:server:getProps', function(props)
    for _, p in ipairs(props) do
        print(p.gunsiteid, p.citizenid, p.x, p.y, p.z)
    end
end)
```

### 8.7 Add a new weapon (or new parts) to the menu
Add the weapon to `Config.Specific` and give every new component a locale entry in all 10 files:
```lua
-- shared/config.lua
Config.Specific["WEAPON_RIFLE_SPRINGFIELD"]["GRIP"] = {
    "COMPONENT_RIFLE_SPRINGFIELD_GRIP",          -- first entry = factory part
    "COMPONENT_RIFLE_SPRINGFIELD_GRIP_IRONWOOD",
}
```
```json
// locales/en.json (repeat translated in the other 9 files)
"COMPONENT_RIFLE_SPRINGFIELD_GRIP_IRONWOOD": "Ironwood Stock"
```
Because the server builds its whitelist from the same config, no other change is needed. Check that the category has a price in `Config.price`, or it will be free.

### 8.8 Log a custom entry to Discord (server, inside this resource)
```lua
Discord.Log('workbench', src, 'Workbench inspected', {
    { 'Workbench ID', prop.gunsiteid },
    { 'Location', ('`%.2f, %.2f, %.2f`'):format(prop.x, prop.y, prop.z) },
})
Discord.Security(src, 'Suspicious request', 'details here')
```

---

## 9. Persistence and database

### 9.1 Tables
The tables are created by `server/database.lua` on start (and by `installation/database.sql` for a manual install):

```sql
CREATE TABLE IF NOT EXISTS `player_weapons` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `serial` varchar(16) NOT NULL,
  `citizenid` varchar(9) NOT NULL,
  `components` varchar(4096) NOT NULL DEFAULT '{}',
  `components_before` varchar(4096) NOT NULL DEFAULT '{}',
  `price` decimal(5,2) NOT NULL DEFAULT 0.00,
  `town` int(11) NOT NULL DEFAULT 0,
  `customname` varchar(32) NULL DEFAULT NULL,
  `engraving` varchar(64) NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `player_weapons_custom` (
  `gunsiteid` varchar(20) NOT NULL,
  `propid` varchar(20) NOT NULL,
  `citizenid` varchar(50) NOT NULL,
  `item` varchar(50) NOT NULL,
  `propdata` longtext NOT NULL,
  PRIMARY KEY (`gunsiteid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `player_weapons_presets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `weapon` varchar(64) NOT NULL,
  `name` varchar(32) NOT NULL,
  `components` varchar(4096) NOT NULL DEFAULT '{}',
  PRIMARY KEY (`id`),
  KEY `idx_citizen_weapon` (`citizenid`, `weapon`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

| Table | Written by | Content |
|---|---|---|
| `player_weapons` | `saveToDatabase` after every purchase / reset | `serial` + `citizenid` identify the weapon; `components` current JSON, `components_before` previous JSON, `price` last price paid |
| `player_weapons_custom` | `createnewprop` / `adminplace` / `removegunsiteprops` / `setaccess` | One row per placed workbench; `propdata` is the JSON record from section 5.2 (`citizenid = 'public'` for admin benches) |
| `player_weapons_presets` | `savePreset` / `deletePreset` | Saved loadouts per player and weapon |

**Automatic setup.** With `Config.AutoDatabase = true` (default) `EnsureDatabase()` runs `CREATE TABLE IF NOT EXISTS` for all three tables and, using `INFORMATION_SCHEMA`, adds the `customname` and `engraving` columns to an existing `player_weapons` table. It never drops or changes existing data. The console prints a green "database tables ready" line, or a red error and the workbenches are not loaded. To install by hand, set `Config.AutoDatabase = false` and import `installation/database.sql`.

### 9.2 Where data lives
- **Weapon components:** primary copy on the weapon item (`item.info.componentshash`); `player_weapons` is a backup. If the item has no components, `getPlayerWeaponComponents` falls back to the database row (checked at most once per weapon per session) and writes the result back to the item.
- **Workbenches:** loaded from `player_weapons_custom` on resource start into `Config.PlayerProps`, then pushed to clients with `rsg-weaponcomp:client:updatePropData` on every change and fetched by joining clients (`RSGCore:Client:OnPlayerLoaded`, `onClientResourceStart`).

---

## 10. Security model

What the script validates on the server, and what other scripts must not assume.

| Area | Checks |
|---|---|
| Purchase / reset | Player exists; cooldown; `wHash` is a number; the player is within `Config.UseDistance` of a workbench; the weapon item is in the player's own inventory (matched by serial; melee / bows by weapon hash); the weapon is not restricted (checked against the item name, not only the client hash) |
| Components | Every `category = component` pair must exist in the config whitelist (built at start from `Config.Shared` and `Config.Specific`) **and be offered for that weapon**: a weapon with its own list for a category only accepts that list, shared categories obey `Config.SharedRequires`. Non-string keys, unknown parts or more than 64 entries refuse the whole request and are logged to the `security` channel (nothing is charged) |
| Price | Calculated server-side with `WeaponComp.ChangePrice`; the client never sends a price. Payment uses `RemoveMoney` and the change is only applied after it succeeds |
| Workbench placement | Cooldown; `coords` is a `vector3` and `heading` a number, all finite (NaN / infinity are rejected); `Config.RequiredJob`; `exports['rsg-gizmo']:IsPlacementValid(src, coords, PlaceDistance + 2.0)`; own distance check; `MaxGunsites` per player; minimum spacing (`gunZoneSize`); the item is removed **before** the row is created |
| Pack-up | Cooldown; owner only (`citizenid` match); within 10.0 of the workbench; refuses when the owner's inventory cannot take the item back, so a workbench is never lost |
| Maintenance | Item removal happens server-side before the client changes anything; repair refuses at 100% quality |
| Scope | The server flips `equippedScope` and the client only mounts or removes the scope when it returns `true` |
| Workbench access | `nearWorkbench` only counts benches the player may use (`everyone`, owner, job or gang match against the server's player data). Only the owner can change access or pack up a bench; public benches cannot be packed up. Admin placement and commands require `Config.AdminPermission` |
| Discount / skill / materials | Discount comes from the player's server-side job and duty state. Locked categories are refused using the XP in player metadata; XP is only awarded for purchases that cost money. Materials are checked before charging, taken after the money, and everything is refunded if one cannot be removed |
| Identity / presets | Text is stripped of control characters and `<>"\`, length-checked (UTF-8 aware) and charged server-side; presets re-run the per-weapon component whitelist, only accept real weapon items and are limited per player and weapon |
| Cooldowns | Per player, cleared on `playerDropped` |

Note for other developers: do not trigger the `rsg-weaponcomp:server:*` events from your own scripts expecting them to bypass checks. They validate the caller's position, inventory and the config whitelist every time.

---

## 11. Discord logging

`server/config.lua` (`DiscordConfig`):

| Option | Description |
|---|---|
| `Enabled` | Master switch |
| `BotName`, `Avatar`, `Footer` | Webhook identity |
| `SecurityPing` | Role mention for `security` alerts, e.g. `'<@&123456789012345678>'` |
| `RsgLogName` | Also send each log through rsg-log under this name (`nil` = off) |
| `Webhooks` | `purchase`, `reset`, `workbench`, `repair`, `security`; leave a URL empty to turn that log off |
| `Colours` | Embed colour per channel (decimal) |
| `ShowIdentifiers` | Which identifiers to show: `license`, `discord`, `steam`, `ip` |
| `ShowComponents` | List every component in purchase logs |

| Channel | Logged when |
|---|---|
| `purchase` | Parts bought or removed |
| `reset` | All modifications removed |
| `workbench` | Workbench placed or packed up |
| `repair` | Repair kit or gun oil used |
| `security` | Invalid component data, restricted weapon, no workbench nearby, out-of-range placement or pack-up, touching another player's workbench |

Messages are queued per webhook (about one per 1.1 s) to respect Discord's rate limit.

---

## 12. Locales

Locales are handled by rsg-core: `@rsg-core/shared/locale.lua` in `shared_scripts`, `locales/*.json` in `files`, and `locale('key')` in code. Set the language in `server.cfg`:
```cfg
setr rsg:locale "de"
```
Languages: `en` (master), `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Every file has the same keys. Key groups: `ui_*` (NUI), `cl_*` (client messages), `sv_*` (server messages and Discord logs), and one key per category name (`BARREL`, `WRAP_TINT`, ...) and per component (`COMPONENT_...`). Add every new key to all 10 files.

---

## 13. Server owner how-tos

**Install**
1. Make sure `rsg-core`, `rsg-inventory`, `rsg-weapons`, `rsg-target`, `rsg-gizmo` and `oxmysql` are started before it.
2. Start the resource: the tables are created automatically (or set `Config.AutoDatabase = false` and import `installation/database.sql`).
3. Add the items from section 6.5 (and any `Config.PartItems` materials).
4. `ensure rsg-weaponcomp` in `server.cfg`.
5. Set your webhooks in `server/config.lua` (optional).

**Restrict workbenches to a job**
```lua
Config.RequiredJob = 'gunsmith' -- job name from your jobs table
```

**Charge from the bank instead of cash**
```lua
Config.PaymentType = 'bank'
```

**Make everything cheaper / free**
```lua
Config.RemovePrice = 0.0
Config.price["BARREL"] = 0.25
```

**Block a weapon**
```lua
Config.WeaponRestriction[#Config.WeaponRestriction + 1] = 'WEAPON_REVOLVER_LEMAT'
```

**Turn off gun oil**
```lua
Config.GunOilItem = nil
```

**Change the workbench model**
```lua
Config.Gunsmithprop = `p_gunsmithprops09x`
```

**Show the workbench name near it**
```lua
Config.gunZoneActive = true
Config.showTextZone = true
```

**Remove a stuck workbench (SQL)**
```sql
DELETE FROM player_weapons_custom WHERE gunsiteid = 'CSID12345678';
```
Restart the resource afterwards so `Config.PlayerProps` reloads, and give the owner a `gunsmith` item if needed.

**Clear a weapon's saved modifications (SQL backup only)**
```sql
DELETE FROM player_weapons WHERE serial = '12345678' AND citizenid = 'ABC12345';
```
The primary copy lives on the weapon item, so the player must also use **Reset** at a workbench.

**Give gunsmiths a discount**
```lua
Config.GunsmithJobs = { gunsmith = { discount = 0.25, requireDuty = true } } -- 25% off while on duty
```

**Turn on skill levels and lock parts behind them**
```lua
Config.Skill.Enabled = true
Config.Skill.Unlocks = { BARREL = 2, GRIP = 3 } -- minimum level per category
```
XP is stored in player metadata under `Config.Skill.MetaKey`; levels come from `Config.Skill.Levels`.

**Require materials for a part**
```lua
Config.PartItems = { BARREL = { { item = 'steel', amount = 2 } } }
```
The item must exist in `rsg-core/shared/items.lua`. The menu shows the materials on the category and in the purchase confirmation.

**Expire abandoned workbenches**
```lua
Config.WorkbenchExpireDays = 30 -- checked hourly; the item is not returned
```

**Look a weapon up from another resource (e.g. rsg-lawman)**
```lua
local rec = exports['rsg-weaponcomp']:GetWeaponRecord(serial)
if rec then print(rec.citizenid, rec.customname, rec.engraving, json.encode(rec.components)) end
```

---

## 14. Troubleshooting

| Problem | Cause / fix |
|---|---|
| Menu won't open | Hold a serialised weapon, stand within targeting range of the workbench, and make sure the weapon is not in `WeaponRestriction`. Melee and bows are the only weapons allowed without an `rsg-weapons` serial |
| "You are too far from a workbench" on purchase | The server checks `Config.UseDistance` from the player's real position; move closer to the workbench |
| Components vanish after drawing the weapon | Start `rsg-weapons` before this resource; use `/loadweapon`; check the weapon item has `info.componentshash` |
| Finishes (tints, materials) look missing | They sometimes need a second pass; the script re-applies them three times after a draw. `/loadweapon` forces it |
| Can't place a workbench | Check `MaxGunsites`, `RequiredJob`, that the `gunsmith` item exists, that you are within `PlaceDistance` and not within `gunZoneSize` of another workbench, and that `rsg-gizmo` is started |
| Placement preview does not appear | `rsg-gizmo` is not running or not listed before this resource; check the F8 console for export errors |
| Workbench placed but item not taken / nothing saved | `IsPlacementValid` or one of the server checks failed; look at the `security` Discord channel and the server console |
| "SQL table doesn't exist" errors | Check the console for a red "database setup failed" line (oxmysql permissions). Otherwise make sure `Config.AutoDatabase` is `true`, or import `installation/database.sql` |
| Players can't use a bench | Its access mode may be `owner`, `job` or `gang`; the owner changes it under **Workbench access**, an admin can place a public bench with `/createworkbench` |
| Can't type a name or preset | Push-to-talk is unavailable while a text box has focus; click outside the box to use it again |
| No Discord logs | Set the webhook URL for each channel in `server/config.lua` and keep `Enabled = true` |
| Wrong language | `setr rsg:locale "xx"` in `server.cfg`; make sure all 10 locale files have the same keys |
| Item box not showing | The `gunsmith`, `weapon_repair_kit` and `weapon_gun_oil` items must exist in `rsg-core/shared/items.lua` |

---

Support: https://rexshack.tebex.store
