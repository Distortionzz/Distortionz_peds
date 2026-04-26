fx_version 'cerulean'
game 'gta5'

author 'Distortionz'
description 'Underground contact with illegal market, reputation, deliveries, police alerts, black market, Qbox/Ox support, Distortionz Notify support, and GitHub version checking'
version '1.4.1'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_script 'client.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

server_script 'server.lua'

dependencies {
    'qb-core',
    'ox_lib',
    'ox_inventory',
    'ox_target',
    'distortionz_notify'
}