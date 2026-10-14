--- Opens the target's inventory for the searching player.
-- @param actor [Player player doing the search]
-- @param target [Player player being searched]
function PlayerSearch:start(actor, target)
  target.requested_search = nil

  actor:open_player_inventory(target)

  target.searcher = actor
  actor.search_target = target
end

--- Ends a search, closing the searched player's inventories and their window for the searcher.
-- @param actor [Player player doing the search, may be nil]
-- @param target [Player player being searched]
function PlayerSearch:stop(actor, target)
  if IsValid(actor) then
    actor.search_target = nil

    Cable.send(actor, 'fl_inventory_close')

    if IsValid(target) then
      actor:close_player_inventory(target)
    end
  end

  if IsValid(target) then
    target.searcher = nil
  end
end

--- Ends the search when the searcher closes the searched player's inventory.
-- @param actor [Player player that closed the inventory]
-- @param inventory [Inventory closed inventory]
function PlayerSearch:OnInventoryClosed(actor, inventory)
  local target = inventory.owner

  if IsValid(target) and target:IsPlayer() and target != actor
  and actor.search_target == target and target.searcher == actor then
    self:stop(actor, target)
  end
end

--- Stops searches that are no longer allowed and clears the searcher of players nobody is searching anymore.
-- @param actor [Player player being checked]
function PlayerSearch:PlayerOneSecond(actor)
  local target = actor.search_target

  if target then
    local success, error_text = hook.Run('CanSearch', actor, target)

    if success == false then
      actor:notify(error_text)
      self:stop(actor, target)
    end
  end

  if !IsValid(actor.searcher) then
    self:stop(nil, actor)
  end
end

--- Checks the search cooldowns, pending requests and existing searches before a search can be requested.
-- @param actor [Player player requesting the search]
-- @param target [Player player to search]
-- @return [Boolean false and String error phrase if the search cannot start, nil otherwise]
function PlayerSearch:CanStartSearch(actor, target)
  local cur_time = CurTime()

  if actor.next_search and actor.next_search > cur_time then
    return false, 'error.search.too_often'
  end

  if target.next_search and target.next_search > cur_time then
    return false, 'error.cant_now'
  end

  if IsValid(target.requested_search) then
    return false, 'error.search.request'
  end

  if IsValid(target.searcher) and target.searcher != actor then
    return false, 'error.search.already'
  end

  local success, error_text = hook.Run('CanSearch', actor, target)

  if success == false then
    return false, error_text
  end
end

--- Requires the searched player to be a valid non-bot player within 100 units who is facing away.
-- @param actor [Player player doing the search]
-- @param target [Player player being searched]
-- @return [Boolean false and String error phrase if the search is not allowed, nil otherwise]
function PlayerSearch:CanSearch(actor, target)
  if !IsValid(target) then
    return false, 'error.invalid_entity'
  end

  if target:IsBot() then
    return false, 'error.invalid_entity'
  end

  if target:facing(actor) then
    return false, 'error.must_not_look'
  end

  if actor:GetPos():DistToSqr(target:GetPos()) > 10000 then
    return false, 'error.too_far'
  end
end

Cable.receive('fl_request_player_search', function(actor, target)
  if !isentity(target) or !IsValid(target) or !target:IsPlayer() or target == actor then return end

  local success, error_text = hook.Run('CanStartSearch', actor, target)

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

  local cur_time = CurTime()

  actor.next_search = actor.next_search and actor.next_search + 5 or cur_time + 5
end)

Cable.receive('fl_start_player_search', function(target, actor)
  local requester = target.requested_search

  if !IsValid(requester) or requester != actor then return end

  target.requested_search = nil

  local success, error_text = hook.Run('CanSearch', actor, target)

  if success == false then
    actor:notify(error_text)

    return
  end

  PlayerSearch:start(actor, target)
end)
