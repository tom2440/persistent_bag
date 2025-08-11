-----------------For support, scripts, and more----------------
--------------- https://discord.gg/wasabiscripts  -------------
---------------------------------------------------------------
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'Wasabi Backpack for Ox Inventory'
version '1.0.4'

client_scripts {
  'client.lua',
  'client_dropped.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',  
  'server.lua',
  'server_dropped.lua'
}

shared_scripts {
  '@ox_lib/init.lua',
  'config.lua'
}

dependencies {
  'ox_inventory',
  'ox_target',
  'oxmysql'  
}