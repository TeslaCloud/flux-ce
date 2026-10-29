--- Client-side receivers with which the server opens and closes the tab menu of the local
-- player, see `Flux.Player:open_tab_menu`.

Cable.receive('fl_tab_menu_open', function(panel_id)
  Flux.TabMenu:open(isstring(panel_id) and panel_id or nil)
end)

Cable.receive('fl_tab_menu_close', function()
  Flux.TabMenu:close()
end)
