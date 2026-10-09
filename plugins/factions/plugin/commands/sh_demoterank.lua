--- Command that moves players one rank down in their faction. Staff with the 'manage_ranks'
-- permission may demote anyone; other players only those whom their own rank lets them
-- demote (see `Factions.can_demote`).

CMD.name = 'DemoteRank'
CMD.description = 'command.demoterank.description'
CMD.syntax = 'command.demoterank.syntax'
CMD.permission = 'user'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 1
CMD.player_arg = 1
CMD.aliases = { 'plydemoterank', 'chardemoterank' }

--- Moves every target that the actor may demote one rank down in their faction, and notifies
-- the targets, staff and the actor. The actor is told when nobody could be demoted.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players matched by the first command argument]
function CMD:on_run(actor, targets)
  local is_staff = !IsValid(actor) or actor:can('manage_ranks')
  local demoted = {}

  for k, v in ipairs(targets) do
    if (is_staff or Factions.can_demote(actor, v)) and v:demote_rank() then
      table.insert(demoted, v)

      v:notify('notification.demote_rank', { rank = v:get_rank_name() }, Color('salmon'))
    end
  end

  if #demoted == 0 then
    Flux.Player:notify(actor, 'error.rank.cannot_demote')

    return
  end

  local arguments = {
    player = get_player_name(actor),
    target = util.player_list_to_string(demoted)
  }

  self:notify_staff('command.demoterank.message', arguments)

  if IsValid(actor) and !actor:can('staff') then
    actor:notify('command.demoterank.message', arguments)
  end
end
