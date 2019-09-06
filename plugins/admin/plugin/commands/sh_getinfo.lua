COMMAND.name = 'GetInfo'
COMMAND.description = 'command.getinfo.description'
COMMAND.syntax = 'command.getinfo.syntax'
COMMAND.permission = 'moderator'
COMMAND.category = 'permission.categories.character_management'
COMMAND.arguments = 1
COMMAND.player_arg = 1
COMMAND.aliases = { 'getinfo', 'info' }

function COMMAND:on_run(player, targets)
    local target = targets[1]
    if (target) then
        target:notify('notification.getinfo', {
            character = target,
            player = player:GetName(),
            steamID = player:SteamID(),
            health = player:Health()
        })
    end
end