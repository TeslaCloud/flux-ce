--- Search requests and starting and ending searches, serverside.

--- How long, in seconds, a request to search a player waits for their answer.
const request_lifetime = 30

--- Remembers that a player has asked to search another player, until the other player
-- answers or `request_lifetime` seconds have passed.
-- @param actor [Player player asking for the search]
-- @param target [Player player to search]
function PlayerSearch:add_request(actor, target)
  target.requested_search = actor
  target.requested_search_until = CurTime() + request_lifetime
end

--- Returns the player whose request to search the target waits for an answer. A request
-- whose time is up, or whose requester has left, is forgotten.
-- @param target [Player player to search]
-- @return [Player the requester, nil if no request is waiting]
function PlayerSearch:get_requester(target)
  local requester = target.requested_search

  if IsValid(requester) and CurTime() < (target.requested_search_until or 0) then
    return requester
  end

  self:clear_request(target)
end

--- Forgets the request to search the target.
-- @param target [Player player to search]
function PlayerSearch:clear_request(target)
  target.requested_search = nil
  target.requested_search_until = nil
end

--- Opens the target's inventory for the searching player, ending the search of anyone else
-- the player is searching.
-- @param actor [Player player doing the search]
-- @param target [Player player being searched]
function PlayerSearch:start(actor, target)
  local previous = actor.search_target

  self:clear_request(target)

  if IsValid(previous) and previous != target then
    self:stop(actor, previous)
  end

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
