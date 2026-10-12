# rsg-weaponcomp

Weapon customisation for **RSG Framework** (RedM). Players place a portable gunsmith workbench, then use it to swap parts, materials, engravings, tints and wraps on the weapon in their hands, with a live 3D preview.

## Features

- Portable gunsmith workbench (usable item) with placement preview, rotation and per-player limits
- NUI customisation menu with live 3D preview and camera controls (zoom, random angle, reset)
- Pay only for the parts you change; the server sets the price and checks it
- Remove all modifications for a configurable percentage of their value
- Components saved on the weapon item and backed up in the database, then re-applied whenever the weapon is drawn
- Scope equip/unequip commands
- Weapon inspection and cleaning with the game's inspection UI and stats (uses a repair kit)
- Optional job restriction, weapon blacklist and `rsg-log` logging
- Translations through ox_lib locales: `en`, `de`, `el`, `es`, `fr`, `it`, `ja`, `nl`, `pl`, `pt-br`, `ro`

## Dependencies

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-weapons](https://github.com/Rexshack-RedM/rsg-weapons)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)
- [oxmysql](https://github.com/overextended/oxmysql)

## Installation

1. Drop `rsg-weaponcomp` into your resources folder.
2. Import `database.sql`.
3. Make sure the `gunsmith` and `weapon_repair_kit` items exist in `rsg-core/shared/items.lua`, or change `Config.Gunsmithitem` / `Config.RepairItem`.
4. Add `ensure rsg-weaponcomp` to your `server.cfg` **after** the dependencies.
5. Set your language in `server.cfg`, for example `setr ox:locale en`.

## Usage

| Action | How |
| --- | --- |
| Place a workbench | Use the `gunsmith` item, aim, rotate with ← / →, hold to place |
| Customise a weapon | Hold the weapon and target the workbench → **Use Gunsmith** |
| Pack up a workbench | In the menu → **Pack Up Workbench** (owner only, item is returned) |
| Inspect / clean weapon | `/w_inspect` (needs a repair kit) |
| Re-apply components | `/loadweapon` |
| Equip / remove scope | `/scope` / `/unscope` |

## Configuration

Everything lives in `config.lua`:

- `Config.Gunsmithitem`, `Config.Gunsmithprop`, `Config.MaxGunsites`, `Config.PlaceDistance` set up the workbench
- `Config.RequiredJob` restricts placing workbenches to one job (`nil` = everyone)
- `Config.PaymentType`, `Config.price`, `Config.RemovePrice` set prices per component category and the reset cost multiplier
- `Config.WeaponRestriction` lists weapons that can't be customised
- `Config.WebhookName` / `Config.WebhookTitle` / `Config.WebhookColour` set up `rsg-log` logging
- `Config.Shared` / `Config.Specific` set which components each weapon group or weapon can use

## Security notes

The server does all money, item and component handling:

- The client never sends a price. The server checks every component against the config whitelist and charges only for what changed.
- The server checks that the weapon being modified is in the player's own inventory.
- Workbench placement checks distance, limits and overlap. The server takes the item before creating the workbench and gives it back only to the owner on pack-up.
- Events have per-player cooldowns.

## Support

- Buy me a coffee: https://buymeacoffee.com/rexshack
