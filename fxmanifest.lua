fx_version 'cerulean'
game 'gta5'

ui_page 'html/index.html'

files {
    'html/index.html'
}

client_scripts {
    'config.lua',
    'client.lua',
    'ambient.lua'
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'config.lua',
    'server.lua'
}
