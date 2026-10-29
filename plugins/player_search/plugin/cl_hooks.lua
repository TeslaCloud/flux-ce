--- Client-side hooks of the Player Search plugin.

--- Adds a search option to the interaction menu of players that are facing away from the local player.
-- @param menu [Panel interaction menu]
-- @param target [Player player the menu was opened for]
function PlayerSearch:CreatePlayerInteractions(menu, target)
  if !target:facing(PLAYER) then
    menu:AddOption(t'ui.search.title', function()
      Cable.send('fl_request_player_search', target)
    end):SetIcon('icon16/magnifier.png')
  end
end
