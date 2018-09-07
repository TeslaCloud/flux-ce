local COMMAND = Command.new("whitelist")

COMMAND.name = "Whitelist"
COMMAND.description = t"whitelist.description"
COMMAND.syntax = t"whitelist.syntax"
COMMAND.category = "player_management"
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.aliases = {"plywhitelist", "givewhitelist", "setwhitelisted"}

function COMMAND:on_run(player, targets, name, bStrict)
  local whitelist = faction.Find(name, (bStrict and true) or false)

  if (whitelist) then
    for k, v in ipairs(targets) do
      v:GiveWhitelist(whitelist.id)
    end

    fl.player:broadcast(L("WhitelistCMD_Message", (IsValid(player) and player:Name()) or "Console", util.player_list_to_string(targets), whitelist.print_name))
  else
    fl.player:notify(player, L("Err_WhitelistNotValid",  name))
  end
end

COMMAND:register()
