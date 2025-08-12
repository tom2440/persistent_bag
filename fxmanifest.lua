fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'tom2440'
description 'Script de sac persistant'
version '1.0.0'

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
