--- Client-side receivers of the Vendors plugin: they open, update and close the trade panel
-- and open the vendor editor when the server says so.

local IsValid = IsValid

Cable.receive('fl_vendor_open', function(vendor, data)
  if IsValid(Vendors.trade_panel) then
    Vendors.trade_panel:close(true)
  end

  if !IsValid(vendor) or !istable(data) then
    Cable.send('fl_vendor_close')

    return
  end

  Vendors.trade_panel = vgui.Create('fl_vendor_trade')
  Vendors.trade_panel:set_vendor(vendor, data)
end)

Cable.receive('fl_vendor_update', function(vendor, data)
  local panel = Vendors.trade_panel

  timer.Remove('fl_vendor_refresh')

  if IsValid(panel) and panel:get_vendor() == vendor and istable(data) then
    panel:set_data(data)
  end
end)

Cable.receive('fl_vendor_change', function(vendor, money, item_id, stock)
  local panel = Vendors.trade_panel

  if IsValid(panel) and panel:get_vendor() == vendor then
    panel:apply_change(money, item_id, stock)
  end
end)

Cable.receive('fl_vendor_close', function()
  if IsValid(Vendors.trade_panel) then
    Vendors.trade_panel:close(true)
  end
end)

Cable.receive('fl_vendor_edit', function(ent_index, data)
  if !isnumber(ent_index) or !istable(data) then return end

  util.wait_for_ent(ent_index, function(vendor)
    if !Vendors:is_vendor(vendor) then return end

    if IsValid(Vendors.editor_panel) then
      Vendors.editor_panel:safe_remove()
    end

    Vendors.editor_panel = vgui.Create('fl_vendor_editor')
    Vendors.editor_panel:set_vendor(vendor, data)
  end, 0.05, 100)
end)
