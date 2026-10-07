CMD.name = 'SetFaction'
CMD.description = 'command.setfaction.description'
CMD.syntax = 'command.setfaction.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 2
CMD.player_arg = 1
CMD.aliases = { 'plytransfer', 'charsetfaction', 'chartransfer' }

--- Returns the translated command description with every registered faction ID listed.
-- @return [String]
function CMD:get_description()
  local factions = {}

  for k, v in pairs(Factions.all()) do
    table.insert(factions, k)
  end

  return t(self.description, { factions = table.concat(factions, ', ') })
end

--- Moves every target into the faction found by name and notifies the targets and staff.
-- @param player [Player the player who ran the command]
-- @param targets [Array<Player> players matched by the first command argument]
-- @param name [String faction ID or name, or a part of either]
-- @param strict=nil [String any extra argument makes the faction lookup exact]
function CMD:on_run(player, targets, name, strict)
  local faction_table = Factions.find(name, (strict and true) or false)

  if faction_table then
    self:notify_staff('command.setfaction.message', {
      player = get_player_name(player),
      target = util.player_list_to_string(targets),
      faction = faction_table.name
    })

    for k, v in ipairs(targets) do
      v:set_faction(faction_table.faction_id)
      v:notify('notification.faction_changed', { faction = faction_table.name }, faction_table.color)
    end
  else
    player:notify('error.faction.invalid', { faction = name })
  end
end
