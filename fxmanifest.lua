fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'hajden'
description 'npc robbery what else to say..'
version '1.0.0'

dependencies {
    'ox_lib',
    'ox_core'
}

files {
    'locales/*.json'
}

shared_scripts {
    '@ox_lib/init.lua',
    '@ox_core/lib/init.lua',
    'config.lua'
}

server_scripts {
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}