--- Starting and ending searches, serverside.

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
