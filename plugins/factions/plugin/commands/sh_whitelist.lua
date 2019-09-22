CMD.name = 'Whitelist'
CMD.description = 'command.whitelist.description'
CMD.syntax = 'command.whitelist.syntax'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 2
CMD.player_arg = 1
CMD.aliases = { 'plywhitelist', 'givewhitelist', 'setwhitelisted' }

function CMD:get_description()
  local factions = {}

  for k, v in pairs(Factions.all()) do
    table.insert(factions, k)
  end

  return t(self.description, { factions = table.concat(factions, ', ') })
end

function CMD:on_run(player, targets, faction_id, strict)
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
    player:notify('error.faction.invalid', { faction = faction_id })
  end
end
