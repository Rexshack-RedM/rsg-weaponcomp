# rsg-weaponcomp

Weapon customisation for **RSG Framework** (RedM). Players place a portable gunsmith workbench, then use it to swap parts, materials, engravings, tints and wraps on the weapon in their hands, with a live 3D preview.

## Features

- Portable gunsmith workbench (usable item) with a placement preview, rotation, range indicator, cancellable set-up and per-player limits
- NUI customisation menu with a live 3D preview of the weapon
- Orbit camera centred on the weapon: rotate with ← / →, zoom, random angle and reset
- Auto part focus: the camera moves to the part being changed (players can switch it off; their choice is remembered)
- The player is frozen, hidden and blocked from all other actions while customising
- **Factory** option on every finish (tints, materials, engravings, wraps, scope), so players only pay for what they actually change
- Removing a modification costs a configurable percentage of its price; **Reset** strips everything back to factory
- Components are saved on the weapon item, backed up in the database, and re-applied whenever the weapon is drawn
- Scope equip/unequip commands
- Weapon inspection and cleaning with the game's inspection UI and stats (uses a repair kit)
- Discord webhook logging for purchases, resets, workbenches, repairs and suspicious activity (optional `rsg-log` mirror)
- Optional job restriction and weapon blacklist
- Fully translated through ox_lib locales — notifications, NUI, prompts, component names and Discord logs: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`

## Dependencies

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-weapons](https://github.com/Rexshack-RedM/rsg-weapons)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)
- [oxmysql](https://github.com/overextended/oxmysql)

## Installation

1. Drop `rsg-weaponcomp` into your resources folder.
2. Import `installation/database.sql`.
3. Make sure the `gunsmith` and `weapon_repair_kit` items exist in `rsg-core/shared/items.lua`, or change `Config.Gunsmithitem` / `Config.RepairItem`.
4. Add `ensure rsg-weaponcomp` to your `server.cfg` **after** the dependencies.
5. Set your language in `server.cfg`, for example `setr ox:locale en`.

## Usage

| Action | How |
| --- | --- |
| Place a workbench | Use the `gunsmith` item, aim, rotate with ← / →, hold to place (the ghost fades when out of range) |
| Customise a weapon | Hold the weapon and target the workbench → **Use Gunsmith** → **Parts & Attachments** |
| Rotate / zoom the camera | ← / → to rotate, scroll to zoom, C for a random angle, hold V to reset |
| Toggle auto part focus | Click **Auto Focus** in the menu's controls bar |
| Remove all modifications | **Reset** in the menu |
| Pack up a workbench | Main menu → **Pack Up Workbench** (owner only, the item is returned) |
| Inspect / clean weapon | `/w_inspect` (cleaning uses one repair kit) |
| Re-apply components | `/loadweapon` |
| Equip / remove scope | `/scope` / `/unscope` |

## Configuration

Everything lives in `shared/config.lua`:

- **Workbench:** `Config.Gunsmithitem`, `Config.Gunsmithprop`, `Config.MaxGunsites`, `Config.PlaceDistance`, `Config.SetupTime`
- **Access:** `Config.RequiredJob` restricts placing workbenches to one job (`nil` = everyone)
- **Pricing:** `Config.PaymentType`, `Config.price` (per category), `Config.RemovePrice` (share of the price charged to remove a part)
- **Blacklist:** `Config.WeaponRestriction` lists weapons that can't be customised
- **Camera:** `Config.distBack` (distance as a multiple of weapon length), `Config.distFov`, `Config.camRotateSpeed`, `Config.prompts` (camera keys)
- **Part focus:** `Config.AutoFocusDefault` and `Config.PartFocus` (where along the weapon, and how close, the camera goes for each category)
- **Components:** `Config.Shared` / `Config.Specific` set which components each weapon group or weapon can use

### Discord logging

Webhooks are set in `server/config.lua`, which is **server-only**, so the URLs are never sent to players. Leave a URL empty to turn that log off.

| Channel | Logged when |
| --- | --- |
| `purchase` | A player buys or removes parts (weapon, serial, price paid, components before and after) |
| `reset` | A player resets a weapon to factory |
| `workbench` | A workbench is placed or packed up (ID, location, how many the player owns) |
| `repair` | A weapon is cleaned with a repair kit |
| `security` | Suspicious activity: components not in the config, restricted weapons, out-of-range placement or pack-up, touching someone else's workbench |

Every embed includes the character name, citizen ID, server ID and coordinates, plus the identifiers you enable in `DiscordConfig.ShowIdentifiers` (license and Discord by default; Steam and IP are off). Other options:

- `DiscordConfig.SecurityPing` pings a role on security alerts, e.g. `'<@&123456789012345678>'`
- `DiscordConfig.RsgLogName` also sends every log through `rsg-log`
- `DiscordConfig.ShowComponents` lists the full component changes in purchase logs

Messages are queued per webhook and sent about once a second, and the queue waits when Discord rate limits it, so busy servers don't lose logs or get the webhook blocked.

### Factory parts

Structural slots (`BARREL`, `GRIP` — the wood stock on long arms — `SIGHT`, `CLIP`, `TUBE`, `MAG`, `STOCK`) use the **first entry** of their list as the weapon's factory part. Every other category gets a **Factory** option (nothing applied) in the menu. Factory parts are never stored or charged. The list of structural slots is `WeaponComp.FactoryCategories` in `shared/utils.lua`.

## Security notes

The server handles all money, items and components:

- The client never sends a price. The server checks every component against the config whitelist, works out the price itself and charges only for what changed.
- The server checks that the weapon being modified is in the player's own inventory, and checks the blacklist against the item rather than the client's weapon hash.
- Workbench placement checks distance, limits and overlap. The server takes the item before creating the workbench and gives it back only to the owner on pack-up.
- Weapon cleaning only repairs the weapon after the server has taken a repair kit.
- Events have per-player cooldowns.

## Upgrading from older versions

Older versions saved the first tint, engraving and grip material of every list onto a weapon on any purchase. Weapons customised before this update may still carry those finishes; using **Reset** at a workbench clears them.

## Support

- Buy me a coffee: https://buymeacoffee.com/rexshack
