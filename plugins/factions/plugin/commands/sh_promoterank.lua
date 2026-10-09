--- Command that moves players one rank up in their faction. Staff with the 'manage_ranks'
-- permission may promote anyone; other players only those whom their own rank lets them
-- promote (see `Factions.can_promote`).

CMD.name = 'PromoteRank'
CMD.description = 'command.promoterank.description'
CMD.syntax = 'command.promoterank.syntax'
CMD.permission = 'user'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 1
CMD.player_arg = 1
CMD.aliases = { 'plypromoterank', 'charpromoterank' }

--- Moves every target that the actor may promote one rank up in their faction, and notifies
-- the targets, staff and the actor. The actor is told when nobody could be promoted.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
function CMD:on_run(actor, targets)
  local is_staff = !IsValid(actor) or actor:can('manage_ranks')
  local promoted = {}

  for k, v in ipairs(targets) do
    if (is_staff or Factions.can_promote(actor, v)) and v:promote_rank() then
      table.insert(promoted, v)

      v:notify('notification.promote_rank', { rank = v:get_rank_name() }, Color('lightgreen'))
    end
  end

  if #promoted == 0 then
    Flux.Player:notify(actor, 'error.rank.cannot_promote')

    return
  end

  local arguments = {
    player = get_player_name(actor),
    target = util.player_list_to_string(promoted)
  }

  self:notify_staff('command.promoterank.message', arguments)

  if IsValid(actor) and !actor:can('staff') then
    actor:notify('command.promoterank.message', arguments)
  end
end
