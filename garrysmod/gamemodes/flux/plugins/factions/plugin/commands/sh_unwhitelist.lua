local COMMAND = Command.new("unwhitelist")

COMMAND.name = "UnWhitelist"
COMMAND.description = "#TakeWhitelistCMD_Description"
COMMAND.syntax = "#TakeWhitelistCMD_Syntax"
COMMAND.category = "player_management"
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.Aliases = {"takewhitelist", "plytakewhitelist", "plyunwhitelist"}

function COMMAND:OnRun(player, targets, name, bStrict)
  local whitelist = faction.Find(name, bStrict)

  if (whitelist) then
    for k, v in ipairs(targets) do
      if (v:HasWhitelist(whitelist.id)) then
        v:TakeWhitelist(whitelist.id)
      elseif (#targets == 1) then
        fl.player:Notify(player, L("Err_TargetNotWhitelisted", v:Name(), whitelist.print_name))

        return
      end
    end

    fl.player:NotifyAll(L("TakeWhitelistCMD_Message", (IsValid(player) and player:Name()) or "Console", util.PlayerListToString(targets), whitelist.print_name))
  else
    fl.player:Notify(player, L("Err_WhitelistNotValid",  name))
  end
end

COMMAND:register()
