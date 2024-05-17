## ADD OPTION IN YOUR MENU FOR MODIFY COMP WEAPON

Basically it would be doing a debug, I think I am very organized and my programming is easy to read
- open event
- basic functions
- functions apply
- Load for inv or command /loadweapon and load selection in menu
- Main Menu
- Menu for options
- Function cam
- Event cam
- Inspection extras
- Extras others off for command
- Start, Stop resource

# in config, 
- 2 notify = 'rnotify' (for send the player, and all errors in ox_lib) or all in 'ox_lib'
- 2 menus = 'menu_base' and 'rsg-basemenu'
- Config.RemovePrice (0 - 1) = 100 % cost remove base price
- can show stats in /w_inspect
- Config permision command acces menu

# in Data/weaponlist
- change prices and locales categorie for names in menu
- all data for components, material and engraving
- system price in data
  
# Admin

```
/customweapon -- open menu
/loadweapon -- refresh skin weapon
/w_damage -- change damage wepaons
/w_inspect -- inspect weapon
/w_scope -- active scope in weapon
```
# option for ox_lib
```lua
 { title = 'Weapon modifications',
    icon = 'fa-solid fa-sack-dollar',
    description = 'Modify a player's weapons!',
    event ='rsg-weaponcomp:client:OpenCreatorWeapon',
    arrow = true
 },
```
# client
```lua
TriggerEvent('rsg-weaponcomp:client:OpenCreatorWeapon')
```
# server
```lua
TriggerClientEvent('rsg-weaponcomp:client:OpenCreatorWeapon', src)
```

# Version oficial or learning thanks
- [gum_weapons](https://github.com/Gum-Core/gum_weapons) -- Gum-Core
- [rsg-weapons](https://github.com/BM-Studio/rsg-weapons) -- BM-Studio
- [rsg-weapons](https://github.com/Rexshack-RedM/rsg-weapons) -- Rexshack-RedM
- [rsg-horses](https://github.com/Rexshack-RedM/rsg-horses)
- [rsg-barbers](https://github.com/Rexshack-RedM/rsg-barbers)
- [rsg-appearance](https://github.com/Rexshack-RedM/rsg-appearance)
- [vorp_weaponsv2](https://github.com/VORPCORE/vorp_weaponsv2) -- VORPCORE
- [qc_weapModifier](https://github.com/Artmines/qc_weapModifier) -- QUANTUM CORE

# Also thank everyone who collaborated during the development, has tested it or participated:
- [rms_dnb](https://github.com/RMS-dnb/),
- [rexshack](https://github.com/Rexshack-RedM/),
- [salahkham](https://www.youtube.com/channel/UC_-sYXe5B4qInE_ZGw6DITg),
- [ttv_artmines_playz](https://github.com/Artmines/),
- [philmcraken](https://github.com/mrskunky69/),
- [jackp_](https://github.com/Jewsie/),
- [Sadicius](https://github.com/Sadicius),
- and there are many others...

# For RSG
