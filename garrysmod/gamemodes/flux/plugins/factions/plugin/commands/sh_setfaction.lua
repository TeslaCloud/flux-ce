local COMMAND = Command.new('setfaction')

COMMAND.name = 'Setfaction'
COMMAND.description = t'set_faction.description'
COMMAND.syntax = t'set_faction.syntax'
COMMAND.category = 'player_management'
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.aliases = { 'plytransfer', 'charsetfaction', 'chartransfer' }

function COMMAND:on_run(player, targets, name, strict)
  local faction_table = faction.find(name, (strict and true) or false)

  if faction_table then
    for k, v in ipairs(targets) do
      v:set_faction(faction_table.faction_id)
    end

    fl.player:broadcast('set_faction.message', { get_player_name(player), util.player_list_to_string(targets), faction_table.print_name })
  else
    player:notify('err.whitelist_not_valid',  name)
  end
end

COMMAND:register()
