<img width="2948" height="497" alt="rsg_framework" src="https://github.com/user-attachments/assets/638791d8-296d-4817-a596-785325c1b83a" />

# 🔧 rsg-weaponcomp
**Weapon components & customization (RSG Core).**

![Platform](https://img.shields.io/badge/platform-RedM-darkred)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

> Open the customization flow **with an item** and **load selections via inventory or `/loadweapon`**. Includes camera helpers and menu pages for options.

---

## 🛠️ Dependencies
- **rsg-core** (framework)  
- **ox_lib** (notifications & locale)  
- **oxmysql** (database)

**License:** GPL‑3.0

---

## ✨ What’s in this resource
- **Open event with item** (uses a usable item to start the flow)  
- **Basic functions**  
- **Functions apply** (apply selected components/finishes)  
- **Load for inventory or command** — `/loadweapon` and load selection in menu  
- **Main Menu**  
- **Menu for options** (components/finishes)  
- **Function cam** (helper camera)  
- **Event cam** (camera events)  
- **Inspection extras**
- **Extras others off for command**  
- **Start, Stop resource**

> ✅ Verified in code:  
> • `Config.Gunsmithitem = 'gunsmith'` (usable item)  
> • `Config.Gunsmithprop = \`p_gunsmithprops09x\`` (placement prop)  
> • `Config.PaymentType = 'cash' | 'bloodmoney'`  
> • Server registers the **usable item** and provides **`/loadweapon`**.  
> • No `/w_inspect` command found in this repository.

---

## ⚙️ Configuration (`config.lua`)
```lua
Config = {}

Config.Debug           = true
Config.PlaceDistance   = 5.0
Config.RepairItem      = 'weapon_repair_kit'
Config.Gunsmithrobbery = 'lockpick'
Config.Gunsmithitem    = 'gunsmith'
Config.Gunsmithprop    = `p_gunsmithprops09x`
Config.MaxGunsites     = 1
Config.MaxWeapon       = 1
Config.PaymentType     = 'cash' -- or 'bloodmoney'

-- Camera offsets
Config.distBack = 0.7
Config.distSide = 0.13
Config.distUp   = 0.05
Config.distFov  = 60.0
```

> Use the **`gunsmith`** item to open the customization flow. Use **`/loadweapon`** to reapply saved selections.

---

## 🕹️ Command
| Command | Description |
|--------|-------------|
| `/loadweapon` | Load/reapply current selection to the weapon in hand. |

---

## 📂 Installation
1. Drop `rsg-weaponcomp` in `resources/[rsg]`.  
2. Ensure database (oxmysql) is running.  
3. Add to `server.cfg`:
   ```cfg
   ensure ox_lib
   ensure oxmysql
   ensure rsg-core
   ensure rsg-weaponcomp
   ```
4. Restart the server.

---
## change inventory/html/app.js
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
---

## 💎 Credits
- **marcuzz** — 🔗 https://github.com/realmarcuzz/  
- **rms_dnb** — 🔗 https://github.com/RMS-dnb/
- **Sadicius** — 🔗 https://github.com/Sadicius  
- **jackp_ (Jewsie)** — 🔗 https://github.com/Jewsie/  
- **artmines** — 🔗 https://github.com/Artmines/
- **Ashley Inkham (YouTube)** — 🔗 https://www.youtube.com/channel/UC_-sYXe5B4qInE_ZGw6DITg
- **RexshackGaming / RSG Framework** — 🔗 https://github.com/Rexshack-RedM
- **RSG / Rexshack‑RedM** — adaptation & maintenance  
- **Community contributors & translators**  
- License: **GPL‑3.0**
