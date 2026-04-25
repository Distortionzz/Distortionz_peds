fx_version 'cerulean'
game 'gta5'

author 'Distortionz'
description 'Underground contact with illegal market, reputation, deliveries, police alerts, black market, Qbox/Ox support, Distortionz Notify support, and GitHub version checking'
version '1.3.3'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_script 'client.lua'
server_script 'server.lua'

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_inventory',
    'distortionz_notify'
}