Config = {}

Config.Debug = false

        -- add code
        -- finish add code
        
Config.CommandPermisions =  'admin' -- can use /customweapon
Config.Notify =             'rnotify' -- 'ox_lib' or 'rnotify'
Config.MenuData =           'rsg-menubase' -- 'menu_base' or 'rsg-menubase'

Config.showStats =          true -- true / false can show stats
Config.RemovePrice =        1.2 -- (0 - 1) = 100 % cost remove component 120%
Config.animationSave =      10000 -- apply components

Config.GunsmithLocations = {
  { 
      name = 'Valentine Gunsmith',
      gunsmithid = 'valgunsmith',
      coords = vector3(-280.98, 778.88, 119.50),
      prompt = 'valguncustom',
      custcoords = vector4(-281.40, 779.86, 119.58, 90.0),
      npcmodel = `u_m_m_rhdgunsmith_01`,
      npccoords = vector4(-280.98, 778.88, 119.50, 4.01),
      jobaccess = 'valgunsmith',
      blipname = 'Valentine Gunsmith',
      blipsprite = 'blip_shop_gunsmith',
      blipscale = 0.2,
      showblip = true
  },
  { 
      name = 'Rhodes Gunsmith',
      gunsmithid = 'rhogunsmith',
      coords = vector3(1322.64, -1323.14, 77.89),
      npcmodel = `u_m_m_rhdgunsmith_01`,
      npccoords = vector4(1322.64, -1323.14, 77.89, 351.73),
      jobaccess = 'rhogunsmith',
      blipname = 'Rhodes Gunsmith',
      blipsprite = 'blip_shop_gunsmith',
      blipscale = 0.2,
      showblip = true
  },
  { 
      name = 'StDenis Gunsmith',
      gunsmithid = 'stdgunsmith',
      coords = vector3(2717.28, -1286.84, 49.64),
      npcmodel = `u_m_m_rhdgunsmith_01`,
      npccoords = vector4(2717.28, -1286.84, 49.64, 37.67),
      jobaccess = 'stdgunsmith',
      blipname = 'StDenis Gunsmith',
      blipsprite = 'blip_shop_gunsmith',
      blipscale = 0.2,
      showblip = true
  },
  { 
      name = 'Tumbleweed Gunsmith',
      gunsmithid = 'tumgunsmith',
      coords = vector3(-5506.44, -2963.92, -0.64),
      npcmodel = `u_m_m_rhdgunsmith_01`,
      npccoords = vector4(-5506.44, -2963.92, -0.64, 105.35),
      jobaccess = 'tumgunsmith',
      blipname = 'Tumbleweed Gunsmith',
      blipsprite = 'blip_shop_gunsmith',
      blipscale = 0.2,
      showblip = true
  },
  { 
      name = 'Annesburg Gunsmith',
      gunsmithid = 'anngunsmith',
      coords = vector3(2948.46, 1319.50, 44.82),
      npcmodel = `u_m_m_rhdgunsmith_01`,
      npccoords = vector4(2948.46, 1319.50, 44.82, 67.53),
      jobaccess = 'anngunsmith',
      blipname = 'Annesburg Gunsmith',
      blipsprite = 'blip_shop_gunsmith',
      blipscale = 0.2,
      showblip = true
  },
}

Config.StartCamObj = true -- false or true small changes in camera

Config.CustomLocations = {
  {
    name = 'Customs',
    prompt = 'val_custom',
    gunsmithid = 'valgunsmith',
    coords = vector3(-280.98, 778.88, 119.50),
    custcoords = vector4(-281.40, 779.86, 119.58, 90.0),
    jobaccess = 'valgunsmith',
  },
}

-------------------------
-- DAMAGE
-----------------------
Config.WeaponDamageModifiers = {
--    HASHKEY       DMG VALUE      MODEL NAME
    [0x1086D041]    = 1.5,           -- Jawbone Knife
    [0x28950C71]    = 10.0,          -- Machete
    [0xDB21AC8C]    = 10.0,          -- Regular Knife
--    HASHKEY       DMG VALUE      MODEL NAME      --
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
-- MODELS
-----------------------
Config.weaponObject = {
    ['WEAPON_REVOLVER_SCHOFIELD'] ='w_revolver_schofield01',
    ['WEAPON_REVOLVER_LEMAT'] ='w_revolver_lemat01',
    ['WEAPON_REVOLVER_DOUBLEACTION'] ='w_revolver_doubleaction01',
    ['WEAPON_REVOLVER_CATTLEMAN'] ='w_revolver_cattleman01',
    ['WEAPON_REVOLVER_NAVY'] = 'w_revolver_navy01',

    ['WEAPON_PISTOL_SEMIAUTO'] ='w_pistol_semiauto01',
    ['WEAPON_PISTOL_MAUSER'] ='w_pistol_mauser01',
    ['WEAPON_PISTOL_VOLCANIC'] ='w_pistol_volcanic01',
    ['WEAPON_PISTOL_M1899'] ='w_pistol_m189902',

    ['WEAPON_REPEATER_WINCHESTER'] ='w_repeater_winchester01',
    ['WEAPON_REPEATER_HENRY'] ='w_repeater_henry01',
    ['WEAPON_REPEATER_EVANS'] ='w_repeater_evans01',
    ['WEAPON_REPEATER_CARBINE'] ='w_repeater_carbine01',

    ['WEAPON_RIFLE_SPRINGFIELD'] ='w_rifle_springfield01',
    ['WEAPON_RIFLE_BOLTACTION'] ='w_rifle_boltaction01',
    ['WEAPON_RIFLE_VARMINT'] ='w_repeater_pumpaction01',
    ['WEAPON_RIFLE_ELEPHANT'] = 'w_dis_rif_elephant01',

    ['WEAPON_SNIPERRIFLE_ROLLINGBLOCK'] ='w_rifle_rollingblock01',
    ['WEAPON_SNIPERRIFLE_CARCANO'] ='w_rifle_carcano01',

    ['WEAPON_SHOTGUN_SEMIAUTO'] ='w_shotgun_semiauto01',
    ['WEAPON_SHOTGUN_SAWEDOFF'] ='w_shotgun_sawed01',
    ['WEAPON_SHOTGUN_REPEATING'] ='w_shotgun_repeating01',
    ['WEAPON_SHOTGUN_PUMP'] ='w_shotgun_pumpaction01',
    ['WEAPON_SHOTGUN_DOUBLEBARREL'] ='w_shotgun_doublebarrel01',

    ['WEAPON_KIT_CAMERA'] ='p_camerabox01x',
    ['WEAPON_KIT_CAMERA_ADVANCED'] ='p_camerabox01x',
    ['WEAPON_LASSO'] =  'w_melee_lasso01',
    ['WEAPON_LASSO_REINFORCED'] =  'w_melee_lasso01',
    ['WEAPON_FISHINGROD'] ='w_melee_fishingpole02',

    ['WEAPON_MELEE_KNIFE'] ='w_melee_knife02',
    ['WEAPON_MELEE_KNIFE_CIVIL_WAR'] ='w_melee_knife16',
    ['WEAPON_MELEE_KNIFE_JAWBONE'] ='w_melee_knife03',
    ['WEAPON_MELEE_KNIFE_MINER'] ='w_melee_knife14',
    ['WEAPON_MELEE_KNIFE_VAMPIRE'] ='w_melee_knife18',
    ['WEAPON_MELEE_CLEAVER'] ='w_melee_hatchet02',
    ['WEAPON_MELEE_HATCHET'] ='w_melee_hatchet01',
    ['WEAPON_MELEE_HATCHET_DOUBLE_BIT'] ='w_melee_hatchet06',
    ['WEAPON_MELEE_HATCHET_HEWING'] ='w_melee_hatchet05',
    ['WEAPON_MELEE_HATCHET_HUNTER'] ='w_melee_hatchet07',
    ['WEAPON_MELEE_HATCHET_VIKING'] ='w_melee_hatchet04',
    ['WEAPON_MELEE_MACHETE_COLLECTOR'] = 'p_machete01x',

    ['WEAPON_THROWN_TOMAHAWK'] ='w_melee_tomahawk01',
    ['WEAPON_THROWN_THROWING_KNIVES'] ='w_melee_knife05',
    ['WEAPON_MELEE_MACHETE'] ='w_melee_machete01',

    ['WEAPON_BOW'] ='w_sp_bowarrow',
    ['WEAPON_BOW_IMPROVED'] ='w_sp_bowarrow',
}

-------------------------
-- EXTRA Webhooks / RANKING
-----------------------
Config.Webhooks = {
    ['weaponCustom'] = '',
}
