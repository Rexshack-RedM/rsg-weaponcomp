fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

game 'rdr3'

description 'rsg-weaponcomp'
version '1.1.5'

shared_script {
    'config.lua',
    'data/weaponslist.lua',
    '@ox_lib/init.lua',
    '@rsg-core/shared/locale.lua',
    'locale/en.lua',
    -- 'locale/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

client_scripts {
    'client/*.lua'
}

dependencies {
    'rsg-core',
    'ox_lib',
}

lua54 'yes'

export 'startWeaponInspection'
export 'InWeaponCustom'