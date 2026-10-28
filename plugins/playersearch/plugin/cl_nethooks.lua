--- Client-side receiver of the Player Search plugin: asks the local player whether they allow
-- another player to search them and sends the answer to the server.

Cable.receive('fl_request_player_search', function(actor)
  if !IsValid(actor) then return end

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
