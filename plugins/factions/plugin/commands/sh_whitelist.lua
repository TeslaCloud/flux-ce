--- Staff command that manages the faction whitelists of players. `/whitelist add <target>
-- <faction>` whitelists players for a faction and `/whitelist remove <target> <faction>`
-- takes that whitelist away again. The faction is named by its whole ID or name.

CMD.name = 'Whitelist'
CMD.description = 'command.whitelist.description'
CMD.category = 'permission.categories.player_management'
CMD.aliases = { 'plywhitelist' }

local add = CMD:subcommand('add')
add.description = 'command.whitelist.add.description'
add.syntax = 'command.whitelist.add.syntax'
add.arguments = 2
add.arg_types = { 'player', 'faction' }

--- Whitelists every target for a faction and notifies the targets who have received the
-- whitelist and staff. The actor is told when none of the targets has received it, because
-- they are on the whitelist already or their data has not been loaded yet.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
-- @param faction_id [String faction ID or name]
function add:on_run(actor, targets, faction_id)
  local faction_table = Factions.find(faction_id)

  if !faction_table then
    Flux.Player:notify(actor, 'error.faction.invalid', { faction = faction_id })

    return
  end

  local given = {}

  for _, target in ipairs(targets) do
    if target:give_whitelist(faction_table.faction_id) then
      given[#given + 1] = target

      target:notify('notification.whitelist_given', { faction = faction_table.name }, faction_table.color)
    end
  end

  if #given == 0 then
    Flux.Player:notify(actor, 'command.whitelist.add.none', { faction = faction_table.name })

    return
  end

  self:notify_staff('command.whitelist.add.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(given),
    faction = faction_table.name
  })
end

local remove = CMD:subcommand('remove')
remove.description = 'command.whitelist.remove.description'
remove.syntax = 'command.whitelist.remove.syntax'
remove.arguments = 2
remove.arg_types = { 'player', 'faction' }

--- Takes the whitelist for a faction away from every target that has it and notifies those
-- targets and staff. The actor is told when none of the targets had it.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
-- @param faction_id [String faction ID or name]
function remove:on_run(actor, targets, faction_id)
  local faction_table = Factions.find(faction_id)

  if !faction_table then
    Flux.Player:notify(actor, 'error.faction.invalid', { faction = faction_id })

    return
  end

  local taken = {}

  for _, target in ipairs(targets) do
    if target:take_whitelist(faction_table.faction_id) then
      taken[#taken + 1] = target

      target:notify('notification.whitelist_taken', { faction = faction_table.name }, Color('salmon'))
    end
  end

  if #taken == 0 then
    Flux.Player:notify(actor, 'command.whitelist.remove.none', { faction = faction_table.name })

    return
  end

  self:notify_staff('command.whitelist.remove.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(taken),
    faction = faction_table.name
  })
end
