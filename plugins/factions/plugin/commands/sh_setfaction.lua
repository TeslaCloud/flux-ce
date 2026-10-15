--- Staff command that moves players into another faction, named by its whole ID or name.

CMD.name = 'SetFaction'
CMD.description = 'command.setfaction.description'
CMD.syntax = 'command.setfaction.syntax'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 2
CMD.arg_types = { 'player', 'faction' }
CMD.aliases = { 'plytransfer', 'charsetfaction', 'chartransfer' }

--- Returns the translated command description with every registered faction ID listed.
-- @return [String]
function CMD:get_description()
  local factions = {}

  for faction_id in pairs(Factions.all()) do
    table.insert(factions, faction_id)
  end

  return t(self.description, { factions = table.concat(factions, ', ') })
end

--- Moves every target into the faction and notifies the targets and staff.
-- Targets without a character are skipped, and so are those whose transfer is refused by
-- `Factions.can_transfer`; the actor is told the reason of every refusal.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
-- @param name [String faction ID or name]
function CMD:on_run(actor, targets, name)
  local faction_table = Factions.find(name)

  if !faction_table then
    Flux.Player:notify(actor, 'error.faction.invalid', { faction = name })

    return
  end

  local transferred = {}

  for _, target in ipairs(targets) do
    if target:IsBot() or target:is_character_loaded() then
      local allowed, reason, arguments = Factions.can_transfer(target, faction_table)

      if allowed then
        table.insert(transferred, target)
      else
        Flux.Player:notify(actor, reason, arguments)
      end
    else
      Flux.Player:notify(actor, 'error.faction.no_character', { target = target:name() })
    end
  end

  if #transferred == 0 then return end

  self:notify_staff('command.setfaction.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(transferred),
    faction = faction_table.name
  })

  for _, target in ipairs(transferred) do
    target:set_faction(faction_table.faction_id)
    target:notify('notification.faction_changed', { faction = faction_table.name }, faction_table.color)
  end
end
