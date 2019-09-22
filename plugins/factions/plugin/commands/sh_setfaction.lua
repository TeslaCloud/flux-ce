CMD.name = 'SetFaction'
CMD.description = 'command.setfaction.description'
CMD.syntax = 'command.setfaction.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 2
CMD.player_arg = 1
CMD.aliases = { 'plytransfer', 'charsetfaction', 'chartransfer' }

function CMD:get_description()
  local factions = {}

  for k, v in pairs(Factions.all()) do
    table.insert(factions, k)
  end

  return t(self.description, { factions = table.concat(factions, ', ') })
end

function CMD:on_run(player, targets, name, strict)
  local faction_table = Factions.find(name, (strict and true) or false)

  if faction_table then
    self:notify_staff('command.setfaction.message', {
      player = get_player_name(player),
      target = util.player_list_to_string(targets),
      faction = faction_table.name
    })

    for k, v in ipairs(targets) do
      v:set_faction(faction_table.faction_id)
      v:notify('notification.faction_changed', { faction = faction_table.name }, faction_table.color)
    end
  else
    player:notify('error.faction.invalid', { faction = name })
  end
end
