local COMMAND = Command.new('setfaction')

COMMAND.name = 'Setfaction'
COMMAND.description = "Change player's faction."
COMMAND.syntax = '<name> <faction> [data]'
COMMAND.category = 'player_management'
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.aliases = { 'plytransfer', 'charsetfaction', 'chartransfer' }

function COMMAND:on_run(player, targets, name, bStrict)
  local factionTable = faction.Find(name, (bStrict and true) or false)

  if factionTable then
    for k, v in ipairs(targets) do
      v:SetFaction(factionTable.faction_id)
    end

    fl.player:broadcast('set_faction.message', { get_player_name(player), util.player_list_to_string(targets), factionTable.print_name })
  else
    player:notify('err.whitelist_not_valid',  name)
  end
end

COMMAND:register()
