fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Forge-Code.xyz'
description 'FarmingCreator mit Hex Menu Api'
version '1.1.0'

shared_scripts {
    'shared/config.lua',
    'shared/consumables_config.lua',
    'shared/consumables_schema.lua',
    'framework/init.lua',
    'locals/languages/de.lua',
    'locals/localiser.lua',
}

client_scripts {
    'client/modules/farming.lua',
    'client/modules/verarbeiter.lua',
    'client/modules/verkäufer.lua',
    'client/modules/consumables.lua',
    'client/modules/consumables_creator_fields.lua',
    'client/consumables_creator.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'shared/sv_config.lua',
    'server/modules/farming.lua',
    'server/modules/verarbeiter.lua',
    'server/modules/verkäufer.lua',
    'server/consumables/consumables_store.lua',
    'server/consumables/consumables_registry.lua',
    'server/consumables/consumables_use_service.lua',
    'server/consumables/consumables_creator_service.lua',
    'server/consumables/consumables_inventory.lua',
    'server/modules/consumables.lua',
    'server/main.lua',
}

dependencies {
    'oxmysql',
    'hex_menu_api',
}
