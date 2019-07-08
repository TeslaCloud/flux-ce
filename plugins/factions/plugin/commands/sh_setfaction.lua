COMMAND.name = 'Setfaction'
COMMAND.description = 'command.setfaction.description'
COMMAND.syntax = 'command.setfaction.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'permission.categories.character_management'
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.aliases = { 'plytransfer', 'charsetfaction', 'chartransfer' }

function COMMAND:get_description()
  local factions = {}

  for k, v in pairs(Factions.all()) do
    table.insert(factions, k)
  end

  return t(self.description, { factions = table.concat(factions, ', ') })
end

function COMMAND:on_run(player, targets, name, strict)
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
    player:notify('error.invalid_faction', { faction = name })
  end
end
