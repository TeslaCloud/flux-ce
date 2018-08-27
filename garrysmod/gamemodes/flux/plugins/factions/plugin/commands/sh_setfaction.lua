local COMMAND = Command.new("setfaction")

COMMAND.name = "Setfaction"
COMMAND.description = "Change player's faction."
COMMAND.syntax = "<name> <faction> [data]"
COMMAND.category = "player_management"
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.aliases = {"plytransfer", "charsetfaction", "chartransfer"}

function COMMAND:on_run(player, targets, name, bStrict)
  local factionTable = faction.Find(name, (bStrict and true) or false)

  if (factionTable) then
    for k, v in ipairs(targets) do
      v:SetFaction(factionTable.id)
    end

    fl.player:NotifyAll(L("SetfactionCMD_Message", (IsValid(player) and player:Name()) or "Console", util.PlayerListToString(targets), factionTable.print_name))
  else
    fl.player:Notify(player, L("Err_WhitelistNotValid",  name))
  end
end

COMMAND:register()
