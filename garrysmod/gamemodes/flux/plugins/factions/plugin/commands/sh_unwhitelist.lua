local COMMAND = Command.new("unwhitelist")

COMMAND.name = "UnWhitelist"
COMMAND.description = t"take_whitelist.description"
COMMAND.syntax = t"take_whitelist.syntax"
COMMAND.category = "player_management"
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.aliases = {"takewhitelist", "plytakewhitelist", "plyunwhitelist"}

function COMMAND:on_run(player, targets, name, bStrict)
  local whitelist = faction.Find(name, bStrict)

  if (whitelist) then
    for k, v in ipairs(targets) do
      if (v:HasWhitelist(whitelist.id)) then
        v:TakeWhitelist(whitelist.id)
      elseif (#targets == 1) then
        fl.player:notify(player, L("Err_TargetNotWhitelisted", v:Name(), whitelist.print_name))

        return
      end
    end

    fl.player:broadcast(L("TakeWhitelistCMD_Message", (IsValid(player) and player:Name()) or "Console", util.player_list_to_string(targets), whitelist.print_name))
  else
    fl.player:notify(player, L("Err_WhitelistNotValid",  name))
  end
end

COMMAND:register()
