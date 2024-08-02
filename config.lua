Config = {}

Config.Debug = false

Config.Notify            = 'ox_lib' -- 'ox_lib' or 'rnotify' notify selection
Config.MenuData          = 'rsg-menubase' -- 'menu_base' or 'rsg-menubase' menu selection

Config.Keybinds          = 'J'
Config.Payment           = 'money' --  'item' or  'money'
Config.PaymentType       = 'cash' -- Payment = money you can select 'cash' or 'bloodmoney' / Payment = item you can select 'cash' or 'bloodmoney'

Config.RemovePrice       = 1.2 -- (0 - 1) = 100 % cost remove component 120%
Config.animationSave     = 10000 -- Waiting time for application or removal components
Config.StartCamObj       = true -- false / true Camera movements with category changes during selection

Config.CommandPermisions = 'admin' -- can use /customweapon 
Config.showStats         = true -- true / false can show stats inspect

Config.CustomLocations = {
  {
    name = 'Customs',
    prompt = 'val_custom',
    gunsmithid = 'valgunsmith',
    coords = vector3(-280.98, 778.88, 119.50),
    custcoords = vector4(-281.40, 779.86, 119.58, 90.0),
    jobaccess = 'valgunsmith',
  },
  {
    name = 'Customs',
    prompt = 'rho_custom',
    gunsmithid = 'rhogunsmith',
    coords = vector3(1323.16, -1321.54, 77.91),
    custcoords = vector4(1323.07, -1322.34, 77.95, 0.0),
    jobaccess = 'rhogunsmith',
  },
  {
    name = 'Customs',
    prompt = 'tum_custom',
    gunsmithid = 'tumgunsmith',
    coords = vector3(-5508.35, -2964.26, -0.54),
    custcoords = vector4(-5507.34, -2963.81, -0.59, 60.0),
    jobaccess = 'tumgunsmith',
  },
  {
    name = 'Customs',
    prompt = 'std_custom',
    gunsmithid = 'stdgunsmith',
    coords = vector3(2715.39, -1285.63, 49.80),
    custcoords = vector4(2715.97, -1286.54, 49.72, 0.0),
    jobaccess = 'stdgunsmith',
  },
  {
    name = 'Customs',
    prompt = 'Ann_custom',
    gunsmithid = 'anngunsmith',
    coords = vector3(-280.98, 778.88, 119.50),
    custcoords = vector4(-281.40, 779.86, 119.58, 90.0),
    jobaccess = 'anngunsmith',
  },
  --[[ 
  -- EXTRA LOCATIONS
  {
    name = 'Customs',
    prompt = 'str_custom',
    gunsmithid = 'strgunsmith',
    coords = vector3(-1752.0, -386.7, 156.52),
    custcoords = vector4(-1752.85, -386.86, 156.48, 60.0),
    jobaccess = 'strgunsmith',
  },
  {
    name = 'Customs',
    prompt = 'blk_custom',
    gunsmithid = 'blkgunsmith',
    coords = vector3(-859.30, -1277.90, 43.66),
    custcoords = vector4(-859.31, -1278.66, 43.50, 6.0),
    jobaccess = 'blkgunsmith',
  },
  {
    name = 'Customs',
    prompt = 'gua_custom',
    gunsmithid = 'guagunsmith',
    coords = vector3(1322.02, -6980.69, 61.97),
    custcoords = vector4(1322.02, -6980.69, 61.97, 6.0),
    jobaccess = 'guagunsmith',
  }, ]]
}

-------------------------
-- DAMAGE
-----------------------
Config.WeaponDamageModifiers = {
--    HASHKEY       DMG VALUE      MODEL NAME
    [0x1086D041]    = 1.5,           -- Jawbone Knife
    [0x28950C71]    = 10.0,          -- Machete
    [0xDB21AC8C]    = 10.0,          -- Regular Knife

--    HASHKEY       DMG VALUE      MODEL NAME 
  --PISTOLS
    [0x020D13FF]    = 2.2,        -- Volcanic Pistol
    [0x5B78B8DD]    = 2.0,        -- M1899 Pistol
    [0x657065D6]    = 2.0,        -- SEMI AUTO Pistol
    [0x8580C63E]    = 2.0,        -- MAUSER Pistol
  --REPEATERS
    [0x95B24592]    = 2.2,        -- HENRY REPEATER
    [0xA84762EC]    = 2.6,        -- WINCHESTER REPEATER
    [0xF5175BA1]    = 2.3,        -- CARBINE REPEATER
    [0x7194721E]    = 2.4,        -- EVANS REPEATER
  --REVOLVERS
    [0x0797FBF5]    = 3.8,        -- DOUBLEACTION REVOLVER
    [0x16D655F7]    = 3.8,        -- CATTLEMAN MEXICAN REVOLVER
    [0x169F59F7]    = 3.8,        -- CATTLEMAN REVOLVER
    [0x7E945C8]     = 3.8,        -- NAVY REVOLVER
    [0x1731B466]    = 3.8,        -- NAVY CROSSOVER REVOLVER
    [0x5B2D26B5]    = 3.0,        -- LEMAT REVOLVER
    [0x7BBD1FF6]    = 3.0,        -- SCHOFIELD REVOLVER
    [0x83DD5617]    = 3.8,        -- DOUBLEACTION GAMBLER REVOLVER
  --RIFLES
    [0x63F46DE6]    = 5.0,        -- SPRINGFIELD RIFLE
    [0x772C8DD6]    = 5.0,        -- BOLT ACTION RIFLE
    [0xDDF7BC1E]    = 5.0,        -- VARMIT RIFLE
  --SHOTGUNS
    [0x1765A8F8]    = 1.5,        -- SAW OFF SHOTGUN
    [0x2250E150]    = 1.5,        -- BARREL EXOTIC SHOTGUN
    [0x31B7B9FE]    = 1.5,        -- PUMP SHOTGUN
    [0x63CA782A]    = 1.5,        -- REPEATING SHOTGUN
    [0x6DFA071B]    = 1.5,        -- DOUBLE BARREL SHOTGUN 
  --BOWS
    [0x88a8505c]    = 1.5,        -- BOW
    [0x6E0F12B]     = 5.0,        -- IMPROVED BOW
}

-------------------------
-- EXTRA Webhooks / RANKING
-----------------------
Config.Webhooks = {
    ['weaponCustom'] = '',
}
