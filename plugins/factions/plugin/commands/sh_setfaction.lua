--- Staff command that gives players the starter kit of a faction, named by its whole ID or
-- name, which makes them members of it. Only factions with a kit can be given this way: the
-- default faction of a species is what its characters are in without one.

CMD.name = 'SetFaction'
CMD.description = 'command.setfaction.description'
CMD.syntax = 'command.setfaction.syntax'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 2
CMD.arg_types = { 'player', 'faction' }
CMD.aliases = { 'plytransfer', 'charsetfaction', 'chartransfer' }

--- Returns the translated command description with the ID of every registered faction that
-- has a kit listed.
-- @return [String]
function CMD:get_description()
  local factions = {}

  for _, faction_table in ipairs(Factions.get_list()) do
    if #faction_table:get_kit() > 0 then
      factions[#factions + 1] = faction_table.faction_id
    end
  end

  return t(self.description, { factions = table.concat(factions, ', ') })
end

--- Checks whether a target can be given the kit of a faction, and tells the actor why not.
-- @param actor [Player the player who ran the command]
-- @param target [Player]
-- @param faction_table [Faction]
-- @return [Boolean]
local function can_receive(actor, target, faction_table)
  if target:IsBot() or !target:is_character_loaded() then
    Flux.Player:notify(actor, 'error.faction.no_character', { target = target:name() })

    return false
  end

  if target:get_species_id() != faction_table.species then
    Flux.Player:notify(actor, 'error.faction.wrong_species', { target = target:name(), faction = faction_table.name })

    return false
  end

  local allowed, reason, arguments = Factions.can_transfer(target, faction_table)

  if !allowed then
    Flux.Player:notify(actor, reason, arguments)
  end

  return allowed
end

--- Gives every target the kit of the faction and notifies the targets and staff. Nothing is
-- given when the faction has no kit. Targets without a character, targets of another species
-- than the faction and those whose transfer is refused by `Factions.can_transfer` are
-- skipped; the actor is told the reason of every refusal and the items that could not be
-- given.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
-- @param name [String faction ID or name]
function CMD:on_run(actor, targets, name)
  local faction_table = Factions.find(name)

  if !faction_table then
    Flux.Player:notify(actor, 'error.faction.invalid', { faction = name })

    return
  end

  if #faction_table:get_kit() == 0 then
    Flux.Player:notify(actor, 'error.faction.no_kit', { faction = faction_table.name })

    return
  end

  local transferred = {}

  for _, target in ipairs(targets) do
    if can_receive(actor, target, faction_table) then
      local missing = Factions.give_kit(target, faction_table)

      if #missing > 0 then
        Flux.Player:notify(actor, 'error.faction.kit_incomplete', {
          target = target:name(),
          items = table.concat(missing, ', ')
        })
      end

      transferred[#transferred + 1] = target

      target:notify('notification.faction_kit_given', { faction = faction_table.name }, faction_table.color)
    end
  end

  if #transferred == 0 then return end

  self:notify_staff('command.setfaction.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(transferred),
    faction = faction_table.name
  })
end
