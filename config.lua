-----------------For support, scripts, and more----------------
--------------- https://discord.gg/wasabiscripts  -------------
---------------------------------------------------------------
Config = {}

Config.checkForUpdates = true -- Check for updates?

Config.OneBagInInventory = true -- Allow only one bag in inventory?

Config.BackpackStorage = {
    slots = 10, -- Slots of backpack storage
    weight = 10000 -- Total weight for backpack
}

-- Distance maximale pour interagir avec un sac posé
Config.TargetDistance = 3.0 -- Distance en mètres

-- Prix du sac à dos pour le remboursement automatique
Config.BagPrice = 200 -- Ajustez ce prix selon la valeur réelle dans vos magasins

-- Modèles 3D pour les sacs
Config.Models = {
    equipped = `p_ld_heist_bag_s`, -- Modèle du sac équipé sur le dos
    dropped = 'prop_cs_heist_bag_01' -- Modèle du sac posé au sol
}

-- Le joueur peut modifier le raccourci clavier dans les paramètres de FiveM (F8 -> Settings -> Keybindings)

Strings = { -- Chaînes de notification
    action_incomplete = 'Action incomplète',
    one_backpack_only = 'Vous ne pouvez avoir qu\'un seul sac à dos !',
    backpack_in_backpack = 'Vous ne pouvez pas mettre un sac à dos dans un autre !',
    no_bag_equipped = 'Vous n\'avez pas de sac à dos équipé !',
    no_bag_found = 'Impossible de trouver un sac à dos dans votre inventaire !',
    no_bag_identifier = 'Ce sac à dos n\'a pas d\'identifiant !',
    use_command_to_drop = 'Utilisez la touche PAGE DOWN pour poser votre sac à dos !', -- Nouvelle chaîne
    too_far_from_bag = 'Vous êtes trop loin du sac à dos', 
    pickup_bag = 'Ramasser le sac',
    open_bag = 'Ouvrir le sac'
}