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

Cable.receive('fl_request_player_search', function(actor)
  if PLAYER:IsBot() then
    Cable.send('fl_start_player_search', actor)

    return
  end

  if IsValid(Flux.tab_menu) then
    Flux.tab_menu:close_menu()
  end

  Derma_Query(t('ui.search.message', { player = actor:name() }), t'ui.search.title',
  t'ui.search.allow', function()
    Cable.send('fl_start_player_search', actor)
  end,
  t'ui.search.resist', function()
    Cable.send('fl_resist_player_search', actor)
  end)
end)
