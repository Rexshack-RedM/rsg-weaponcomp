fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-weaponcomp'
version '3.3.0'

lua54 'yes'
shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua',
    'server/discord.lua',
    'server/server.lua',
    'server/versionchecker.lua',
}

ui_page 'html/index.html'

files {
    'html/*.html',
    'html/*.css',
    'html/*.js',
    'html/**/*',
    'locales/*.json',
}

dependencies {
    'rsg-core',
    'rsg-inventory',
    'rsg-weapons',
    'rsg-target',
    'oxmysql',
}
