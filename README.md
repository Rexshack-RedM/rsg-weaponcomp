# ADD OPTION IN YOUR MENU FOR MODIFY COMP WEAPON

Basically it would be doing a debug, I think I am very organized and my programming is easy to read
- open event with item
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
- Config.RemovePrice (0 - 1) = 100 % cost remove base price
- can show stats in /w_inspect
- Config permision command acces menu
- change prices 
- all data for components, material and engraving

# Commands

```
/loadweapon -- refresh skin weapon
/w_inspect -- inspect weapon need item weapon_repair_kit
```

# add sql
```sql
CREATE TABLE `hdrp_weapons_custom` (
    `gunsiteid` VARCHAR(20) NOT NULL,
    `propid` VARCHAR(20) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `item` VARCHAR(50) NOT NULL,
    `propdata` LONGTEXT NOT NULL,
    PRIMARY KEY (`gunsiteid`)
);
```
# add item
```lua
    gunsmith = { name = 'gunsmith', label = 'Gun craft', weight = 12000, type = 'item', image = 'guncraft.png', unique = false, useable = true,  shouldClose = true, description = 'Placeholder'},

```

# change inventory/html/app.js
- https://github.com/Rexshack-RedM/rsg-inventory/blob/main/html/app.js#L992C1-L1016C11
```js
generateTooltipContent(item) {
    if (!item) {
        return "";
    }

    let content = `<div class="custom-tooltip"><div class="tooltip-header">${item.label}</div><hr class="tooltip-divider">`;

    const description = item.info?.description?.replace(/\n/g, "<br>") 
        || item.description?.replace(/\n/g, "<br>") 
        || "No description available.";

    const renderInfo = (obj, indent = 0) => {
        let html = "";
        for (const [key, value] of Object.entries(obj)) {
            if (key === "description" || key === "lastUpdate" || key === "componentshash") continue;

            const padding = "&nbsp;".repeat(indent * 4);
            if (typeof value === "object" && value !== null && !Array.isArray(value)) {
                html += `<div class="tooltip-info"><span class="tooltip-info-key">${padding}${this.formatKey(key)}:</span></div>`;
                html += renderInfo(value, indent + 1);
            } else {
                html += `<div class="tooltip-info"><span class="tooltip-info-key">${padding}${this.formatKey(key)}:</span> ${value}</div>`;
            }
        }
        return html;
    };

    if (item.info && Object.keys(item.info).length > 0) {
        content += renderInfo(item.info);
    }

    content += `<div class="tooltip-description">${description}</div>`;
    content += `<div class="tooltip-weight"><i class="fas fa-weight-hanging"></i> ${item.weight != null ? (item.weight / 1000).toFixed(1) : "N/A"}kg</div>`;
    content += `</div>`;

    return content;
}
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
- [marcuzz](https://github.com/realmarcuzz/),
- [rms_dnb](https://github.com/RMS-dnb/),
- [rexshack](https://github.com/Rexshack-RedM/),
- [philmcraken](https://github.com/mrskunky69/),
- [Sadicius](https://github.com/Sadicius),
- [jackp_](https://github.com/Jewsie/), [ttv_artmines_playz](https://github.com/Artmines/), [salahkham](https://www.youtube.com/channel/UC_-sYXe5B4qInE_ZGw6DITg),
- and there are many others...

# For RSG
