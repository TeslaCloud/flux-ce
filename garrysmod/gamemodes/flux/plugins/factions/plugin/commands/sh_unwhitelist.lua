local COMMAND = Command("unwhitelist")

COMMAND.Name = "UnWhitelist"
COMMAND.Description = "#TakeWhitelistCMD_Description"
COMMAND.Syntax = "#TakeWhitelistCMD_Syntax"
COMMAND.Category = "player_management"
COMMAND.Arguments = 2
COMMAND.PlayerArg = 1
COMMAND.Aliases = {"takewhitelist", "plytakewhitelist", "plyunwhitelist"}

function COMMAND:OnRun(player, targets, name, bStrict)
  local whitelist = faction.Find(name, bStrict)

  if (whitelist) then
    for k, v in ipairs(targets) do
      if (v:HasWhitelist(whitelist.id)) then
        v:TakeWhitelist(whitelist.id)
      elseif (#targets == 1) then
        fl.player:Notify(player, L("Err_TargetNotWhitelisted", v:Name(), whitelist.PrintName))

        return
      end
    end

    fl.player:NotifyAll(L("TakeWhitelistCMD_Message", (IsValid(player) and player:Name()) or "Console", util.PlayerListToString(targets), whitelist.PrintName))
  else
    fl.player:Notify(player, L("Err_WhitelistNotValid",  name))
  end
end

COMMAND:Register()
