local COMMAND = Command.new('unwhitelist')
COMMAND.name = 'UnWhitelist'
COMMAND.description = 'take_whitelist.description'
COMMAND.syntax = 'take_whitelist.syntax'
COMMAND.permission = 'moderator'
COMMAND.category = 'categories.player_management'
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.aliases = { 'takewhitelist', 'plytakewhitelist', 'plyunwhitelist' }

function COMMAND:get_description()
  local factions = {}

  for k, v in pairs(Factions.all()) do
    table.insert(factions, k)
  end

  return t(self.description, table.concat(factions, ', '))
end

function COMMAND:on_run(player, targets, name, strict)
  local whitelist = Factions.find(name, strict)

  if whitelist then
    for k, v in ipairs(targets) do
      if v:has_whitelist(whitelist.faction_id) then
        v:take_whitelist(whitelist.faction_id)
      elseif #targets == 1 then
        player:notify('err.target_not_whitelisted', { v:name(), whitelist.name })

        return
      end
    end

    Flux.Player:broadcast('take_whitelist.message', { get_player_name(player), util.player_list_to_string(targets), whitelist.name })
  else
    player:notify('err.whitelist_not_valid',  name)
  end
end

COMMAND:register()
