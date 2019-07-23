COMMAND.name = 'UnWhitelist'
COMMAND.description = 'command.unwhitelist.description'
COMMAND.syntax = 'command.unwhitelist.syntax'
COMMAND.permission = 'moderator'
COMMAND.category = 'permission.categories.player_management'
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.aliases = { 'takewhitelist', 'plytakewhitelist', 'plyunwhitelist' }

function COMMAND:get_description()
  local factions = {}

  for k, v in pairs(Factions.all()) do
    table.insert(factions, k)
  end

  return t(self.description, { factions = table.concat(factions, ', ') })
end

function COMMAND:on_run(player, targets, faction_id, strict)
  local whitelist = Factions.find(faction_id, strict)

  if whitelist then
    for k, v in ipairs(targets) do
      if v:has_whitelist(whitelist.faction_id) then
        v:take_whitelist(whitelist.faction_id)
        v:notify('notification.whitelist_taken', { faction = whitelist.name }, Color('salmon'))
      end
    end

    self:notify_staff('command.unwhitelist.message', {
      player = get_player_name(player),
      target = util.player_list_to_string(targets),
      faction = whitelist.name
    })
  else
    player:notify('error.faction.invalid', { faction = faction_id })
  end
end
