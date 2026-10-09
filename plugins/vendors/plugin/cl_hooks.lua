--- Client side of the Vendors plugin: draws the name and the description of the vendor that
-- is looked at, opens, updates and closes the trade panel and the vendor editor when the
-- server says so, and asks for fresh prices when the inventory of the local player changes
-- while trading. The trade panel is kept in `Vendors.trade_panel` and the editor in
-- `Vendors.editor_panel`.

local target_distance = 300
local refresh_delay = 0.3

--- Draws the name and the description of the vendor that the local player is looking at
-- above its head. It is drawn from here rather than as an ordinary target ID, because those
-- are hidden when the feet of the entity are out of sight, as they are behind a counter.
function Vendors:HUDDrawTargetID()
  if !IsValid(PLAYER) or !PLAYER:Alive() then return end

  local trace = PLAYER:GetEyeTraceNoCursor()
  local entity = trace.Entity

  if !self:is_vendor(entity) then return end

  local distance = EyePos():Distance(trace.HitPos)

  if distance > target_distance then return end

  local screen_pos = (entity:GetPos() + Vector(0, 0, entity:OBBMaxs().z + 10)):ToScreen()

  if !screen_pos.visible then return end

  local alpha = 255 - 255 * (distance / target_distance)
  local name = entity:get_vendor_name()
  local name_font = Theme.get_font('tooltip_large')
  local desc_font = Theme.get_font('tooltip_normal')
  local name_w, name_h = util.text_size(name, name_font)
  local description = entity:get_vendor_description()
  local lines = description != '' and util.wrap_text(description, desc_font, ScrW() * 0.33, 0) or {}
  local height = name_h

  for k, v in ipairs(lines) do
    local line_w, line_h = util.text_size(v, desc_font)

    height = height + line_h
  end

  local x, y = screen_pos.x, screen_pos.y - height
  local outline_color = color_black:alpha(alpha)

  draw.SimpleTextOutlined(
    name,
    name_font,
    x - name_w * 0.5,
    y,
    Theme.get_color('accent_light'):alpha(alpha),
    nil,
    nil,
    1,
    outline_color
  )

  y = y + name_h

  for k, v in ipairs(lines) do
    local line_w, line_h = util.text_size(v, desc_font)

    draw.SimpleTextOutlined(v, desc_font, x - line_w * 0.5, y, color_white:alpha(alpha), nil, nil, 1, outline_color)

    y = y + line_h
  end
end

--- Asks the server for fresh prices shortly after an inventory of the local player has
-- changed while the trade panel is open, unless the server sends them first.
-- @param inventory [Inventory the inventory that has been received]
function Vendors:OnInventorySync(inventory)
  if !IsValid(self.trade_panel) or inventory.owner != PLAYER then return end

  timer.Create('fl_vendor_refresh', refresh_delay, 1, function()
    local panel = Vendors.trade_panel

    if IsValid(panel) and IsValid(panel:get_vendor()) then
      Cable.send('fl_vendor_refresh', panel:get_vendor())
    end
  end)
end

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
