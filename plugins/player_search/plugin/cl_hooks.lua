--- Client-side hooks of the Player Search plugin.

--- Adds a search option to the interactions of players that are facing away from the local player.
-- @param options [List<Map> options of the interaction menu, changed in place]
-- @param target [Player player the menu was opened for]
function PlayerSearch:AdjustPlayerInteractions(options, target)
  if !target:facing(PLAYER) then
    options[#options + 1] = {
      id = 'search',
      text = t'ui.search.title',
      icon = 'icon16/magnifier.png',
      callback = function()
        Cable.send('fl_request_player_search', target)
      end
    }
  end
end
