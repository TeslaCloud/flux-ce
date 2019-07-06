COMMAND.name = 'Whitelist'
COMMAND.description = 'command.whitelist.description'
COMMAND.syntax = 'command.whitelist.syntax'
COMMAND.permission = 'moderator'
COMMAND.category = 'permission.categories.player_management'
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.aliases = { 'plywhitelist', 'givewhitelist', 'setwhitelisted' }

function COMMAND:get_description()
  local factions = {}

  for k, v in pairs(Factions.all()) do
    table.insert(factions, k)
  end

  return t(self.description, { factions = table.concat(factions, ', ') })
end

function COMMAND:on_run(player, targets, faction_id, strict)
  local whitelist = Factions.find(faction_id, (strict and true) or false)

  if whitelist then
    for k, v in ipairs(targets) do
      v:give_whitelist(whitelist.faction_id)
      v:notify('notification.whitelist_given', { faction = whitelist.name }, whitelist.color)
    end

    self:notify_staff('command.whitelist.message', {
      player = get_player_name(player),
      target = util.player_list_to_string(targets),
      faction = whitelist.name
    })
  else
    player:notify('error.invalid_faction', faction_id)
  end
end
