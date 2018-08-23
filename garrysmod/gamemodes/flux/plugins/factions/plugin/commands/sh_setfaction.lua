local COMMAND = Command("setfaction")

COMMAND.name = "Setfaction"
COMMAND.description = "Change player's faction."
COMMAND.Syntax = "<name> <faction> [data]"
COMMAND.category = "player_management"
COMMAND.Arguments = 2
COMMAND.PlayerArg = 1
COMMAND.Aliases = {"plytransfer", "charsetfaction", "chartransfer"}

function COMMAND:OnRun(player, targets, name, bStrict)
  local factionTable = faction.Find(name, (bStrict and true) or false)

  if (factionTable) then
    for k, v in ipairs(targets) do
      v:SetFaction(factionTable.id)
    end

    fl.player:NotifyAll(L("SetfactionCMD_Message", (IsValid(player) and player:name()) or "Console", util.PlayerListToString(targets), factionTable.print_name))
  else
    fl.player:Notify(player, L("Err_WhitelistNotValid",  name))
  end
end

COMMAND:register()
