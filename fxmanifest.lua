fx_version 'cerulean'
game 'gta5'

author 'Distortionz'
description 'Distortionz RobPed - Rob ambient NPC peds for cash, dirty money, or items'
version '1.0.1'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua',
    'version_check.lua'
}

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory'
}