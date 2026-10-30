--- Server-side hooks of the Player Search plugin: the checks of whether a search may be asked
-- for, start and go on, and the end of a search when its inventory is closed.

--- Ends the search when the searcher closes the searched player's inventory.
-- @param actor [Player player that closed the inventory]
-- @param inventory [Inventory closed inventory]
function PlayerSearch:InventoryClosed(actor, inventory)
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
    local success, error_text = hook.Run('PlayerCanSearch', actor, target)

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
function PlayerSearch:PlayerCanStartSearch(actor, target)
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

  --- Called when a player asks to search another player, when the searched player allows the
  -- search and every second while it lasts.
  -- @param actor [Player player doing the search]
  -- @param target [Player player being searched]
  -- @return [Boolean false to refuse or end the search, String error phrase shown to the searcher]
  local success, error_text = hook.Run('PlayerCanSearch', actor, target)

  if success == false then
    return false, error_text
  end
end

--- Requires the searcher to be alive and the searched player to be a valid non-bot player
-- within 100 units of the eyes of the searcher who is facing away.
-- @param actor [Player player doing the search]
-- @param target [Player player being searched]
-- @return [Boolean false and String error phrase if the search is not allowed, nil otherwise]
function PlayerSearch:PlayerCanSearch(actor, target)
  if !IsValid(target) then
    return false, 'error.invalid_entity'
  end

  if target:IsBot() then
    return false, 'error.invalid_entity'
  end

  if target:facing(actor) then
    return false, 'error.must_not_look'
  end

  if !actor:is_in_reach(target, 100) then
    return false, 'error.too_far'
  end
end
