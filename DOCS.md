# rsg-weaponcomp – Docs (v3.3.0)

## Contents
1. Files
2. How it works
3. Configuration
4. Events, callbacks and commands
5. Database
6. Security
7. Server owner how-tos
8. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-inventory`, `rsg-weapons`, `rsg-target`, `oxmysql` |
| `shared/config.lua` | Workbench, items, camera, commands, part focus |
| `shared/utils.lua` | Shared helpers |
| `client/client.lua` | Customisation menu, camera, preview, workbench props |
| `client/inhands.lua` | Re-apply components when a weapon is drawn, scope commands |
| `client/inspect.lua` | Weapon inspection and cleaning |
| `client/maintenance.lua` | Gun oil |
| `client/propplace.lua` | Workbench placement preview |
| `client/dataview.lua` | Buffer helper |
| `server/server.lua` | Purchases, reset, workbenches, repair, gun oil |
| `server/config.lua`, `server/discord.lua` | Server-only config and Discord logging |
| `server/versionchecker.lua` | GitHub version check |
| `html/` | NUI customisation menu |
| `installation/database.sql` | Manual database install |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

## 2. How it works
- Players place a portable **gunsmith workbench** (the `gunsmith` item), with a placement preview, rotation, range indicator and a cancellable set-up.
- At a workbench they open the NUI menu for the weapon in their hands: parts, materials, engravings, tints and wraps, with a live 3D preview.
- Orbit camera around the weapon (← / → rotate, zoom, random angle, reset). Auto part focus moves the camera to the part being changed; players can switch it off and the choice is remembered.
- The player is frozen, hidden and blocked from other actions while customising.
- Every finish has a **Factory** option, so players only pay for what they change. Removing a modification costs a percentage of its price; **Reset** strips back to factory.
- Components are saved on the weapon item, backed up in the database and re-applied when the weapon is drawn.
- Condition and cleanliness bars in the menu, with **Clean (Gun Oil)** and **Repair (Repair Kit)** options.
- Gun oil is a cheap clean that removes dirt and soot anywhere (use the item with a weapon in hand). Repair kits restore condition.

## 3. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `PlaceDistance` | `5.0` | Workbench placement range |
| `UseDistance` | `6.0` | Server-checked distance from a workbench to buy/reset |
| `SetupTime` | `10000` | ms to set up a workbench (cancellable) |
| `RepairItem` | `'weapon_repair_kit'` | Repair item |
| `GunOilItem` / `GunOilTime` | `'weapon_gun_oil'` / `6000` | Gun oil item and animation time |
| `Gunsmithitem` | `'gunsmith'` | Workbench item |
| `RequiredJob` | `nil` | Job needed to place a workbench |
| `Gunsmithprop` | `p_gunsmithprops09x` | Workbench model |
| `MaxGunsites` | `6` | Workbenches per player |
| `PaymentType` | `'cash'` | Account charged |
| `gunZoneActive`, `gunZoneSize`, `showTextZone` | | Zone options |
| `distBack`, `distFov` | `0.7`, `60.0` | Camera |
| `showStats` | `true` | Show weapon stats |
| `Commandinspect` | `'w_inspect'` | Inspect command |
| `Commandloadweapon` | `'loadweapon'` | Reload components command |
| `Commandequipscope` / `Commanddesequipscope` | `'scope'` / `'unscope'` | Scope commands |
| `prompts` | table | Camera control keys |
| `camRotateSpeed` | `90.0` | Orbit speed (deg/s) |
| `AutoFocusDefault`, `PartFocus` | | Auto part focus defaults and per-part positions |

Server-only settings (prices, blacklist, webhooks) are in `server/config.lua`; never add it to `shared_scripts`.

## 4. Events, callbacks and commands
| Name | Side | Notes |
|---|---|---|
| `rsg-weaponcomp:server:purchase` | server event | `(serial, wHash, weaponName, comps)` |
| `rsg-weaponcomp:server:reset` | server event | `(serial, wHash, weaponName)` |
| `rsg-weaponcomp:server:getPlayerWeaponComponents` | callback | `(serial, weaponName)` |
| `rsg-weaponcomp:server:equipScope` / `unequipScope` | callbacks | `(serial)` |
| `rsg-weaponcomp:server:getProps` / `countprop` | callbacks | Workbench list and count |
| `rsg-weaponcomp:server:createnewprop` | server event | `(coords, heading)` |
| `rsg-weaponcomp:server:removegunsiteprops` | server event | `(propid)` pack up a workbench |
| `rsg-weaponcomp:server:useRepairKit` / `useGunOil` | callbacks | `(serial)` |
| `rsg-weaponcomp:client:ExitCam` | client event | Leave the customisation camera |
| `rsg-weaponcomp:client:reloadWeapon` | client event | `(force)` re-apply components |
| `rsg-weaponcomp:client:InspectionWeapon` | client event | Inspect |
| `rsg-weaponcomp:client:oilWeapon` | client event | Gun oil |
| `rsg-weaponcomp:client:createprop`, `setupgunzone`, `confirmpackup`, `updatePropData`, `animationSaved` | client events | Workbench handling |

| Command | Who | What |
|---|---|---|
| `/w_inspect` | everyone | Inspect and clean the held weapon |
| `/loadweapon` | everyone | Re-apply saved components |
| `/scope`, `/unscope` | everyone | Equip / remove the scope |

Command names follow the `Config.Command*` values.

## 5. Database
- `player_weapons`: `serial`, `citizenid`, `components`, `components_before`, `price`, `town` (component backup per weapon).
- `player_weapons_custom`: `gunsiteid`, `propid`, `citizenid`, `item`, `propdata` (placed workbenches).

Import `installation/database.sql` if the tables aren't created automatically.

## 6. Security
Purchases and resets are validated on the server (distance to a workbench, ownership of the weapon by serial, payment before applying). Workbench count and job restriction are enforced server-side. Discord webhooks log purchases, resets, workbenches, repairs and suspicious activity (optional rsg-log mirror).

## 7. How-tos
- Restrict workbenches to a job: `Config.RequiredJob = 'gunsmith'`.
- Items needed in `items.lua`: `gunsmith`, `weapon_repair_kit`, `weapon_gun_oil`.
- Language: `setr rsg:locale "de"` in server.cfg.

## 8. Troubleshooting
| Problem | Fix |
|---|---|
| Menu won't open | Hold a weapon and stand within `UseDistance` of a workbench |
| Components vanish | Start rsg-weapons first; use `/loadweapon` |
| Can't place a workbench | Check `MaxGunsites`, `RequiredJob` and the item |
| No Discord logs | Set webhook URLs in `server/config.lua` |

Support the Project : https://rexshack.tebex.store/
