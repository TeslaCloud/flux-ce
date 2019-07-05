local COMMAND = Command.new('setfaction')
COMMAND.name = 'Setfaction'
COMMAND.description = 'command.set_faction.description'
COMMAND.syntax = 'command.set_faction.syntax'
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

  return t(self.description, table.concat(factions, ', '))
end

function COMMAND:on_run(player, targets, name, strict)
  local faction_table = Factions.find(name, (strict and true) or false)

  if faction_table then
    for k, v in ipairs(targets) do
      v:set_faction(faction_table.faction_id)
    end

    self:notify_staff('set_faction.message', { get_player_name(player), util.player_list_to_string(targets), faction_table.name })
  else
    player:notify('error.whitelist_not_valid',  name)
  end
end

COMMAND:register()
