local COMMAND = Command("whitelist")

COMMAND.Name = "Whitelist"
COMMAND.Description = "#WhitelistCMD_Description"
COMMAND.Syntax = "#WhitelistCMD_Syntax"
COMMAND.Category = "player_management"
COMMAND.Arguments = 2
COMMAND.PlayerArg = 1
COMMAND.Aliases = {"plywhitelist", "givewhitelist", "setwhitelisted"}

function COMMAND:OnRun(player, targets, name, bStrict)
  local whitelist = faction.Find(name, (bStrict and true) or false)

  if (whitelist) then
    for k, v in ipairs(targets) do
      v:GiveWhitelist(whitelist.id)
    end

    fl.player:NotifyAll(L("WhitelistCMD_Message", (IsValid(player) and player:Name()) or "Console", util.PlayerListToString(targets), whitelist.PrintName))
  else
    fl.player:Notify(player, L("Err_WhitelistNotValid",  name))
  end
end

COMMAND:Register()
