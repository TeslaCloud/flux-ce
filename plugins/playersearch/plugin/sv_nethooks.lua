--- Server-side receivers of the Player Search plugin: pass the request for a search on to the
-- player to search, and start the search or tell the searcher that it was resisted once that
-- player answers.

Cable.receive('fl_request_player_search', function(actor, target)
  if !isentity(target) or !IsValid(target) or !target:IsPlayer() or target == actor then return end

  --- Called when a player asks to search another player, before the request reaches them.
  -- @param actor [Player player asking for the search]
  -- @param target [Player player to search]
  -- @return [Boolean false to refuse the request, String error phrase shown to the player]
  local success, error_text = hook.Run('PlayerCanStartSearch', actor, target)

  if success != false then
    target.requested_search = actor

    Cable.send(target, 'fl_request_player_search', actor)
  else
    actor:notify(error_text)
  end

  local cur_time = CurTime()

  actor.next_search = (!actor.next_search or actor.next_search < cur_time) and cur_time + 1 or actor.next_search + 10
  target.next_search = cur_time + 1
end)

Cable.receive('fl_resist_player_search', function(target, actor)
  local requester = target.requested_search

  if !IsValid(requester) or requester != actor then return end

  actor:notify('notification.search.resist', { player = target })

  target.requested_search = nil
  actor.next_search = (actor.next_search or CurTime()) + 5
end)

Cable.receive('fl_start_player_search', function(target, actor)
  local requester = target.requested_search

  if !IsValid(requester) or requester != actor then return end

  target.requested_search = nil

  local success, error_text = hook.Run('PlayerCanSearch', actor, target)

  if success == false then
    actor:notify(error_text)

    return
  end

  PlayerSearch:start(actor, target)
end)
