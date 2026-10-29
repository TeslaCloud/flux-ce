--- Client-side receiver of the Currencies plugin: the order to rebuild the open money panels.

local IsValid = IsValid

Cable.receive('fl_rebuild_currency_panel', function()
  for _, money_panel in pairs(Flux.money_panels) do
    if IsValid(money_panel) then
      money_panel:rebuild()
    end
  end
end)
