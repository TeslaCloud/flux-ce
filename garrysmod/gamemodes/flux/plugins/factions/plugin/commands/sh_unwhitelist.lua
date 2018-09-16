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

  if whitelist then
    for k, v in ipairs(targets) do
      if v:HasWhitelist(whitelist.faction_id) then
        v:TakeWhitelist(whitelist.faction_id)
      elseif #targets == 1 then
        player:notify("err.target_not_whitelisted", { v:Name(), whitelist.print_name })
        return
      end
    end

    fl.player:broadcast("take_whitelist.message", { get_player_name(player), util.player_list_to_string(targets), whitelist.print_name })
  else
    player:notify('err.whitelist_not_valid',  name)
  end
end

COMMAND:register()
