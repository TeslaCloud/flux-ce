--- Client side of the Vendors plugin: draws the name and the description of the vendor that
-- is looked at and asks for fresh prices when the inventory of the local player changes
-- while trading. The trade panel is kept in `Vendors.trade_panel` and the editor in
-- `Vendors.editor_panel`.

local IsValid = IsValid
local text_size = util.text_size

local target_distance = 300
local refresh_delay = 0.3

--- Returns the description of a vendor broken into lines that fit the target ID. The lines
-- are kept on the entity and made again only when the description or the width changes.
-- @param entity [Entity the vendor]
-- @param font [String font the lines are drawn with]
-- @param width [Number widest line in pixels]
-- @return [List<String> the lines, none if the vendor has no description]
local function get_description_lines(entity, font, width)
  local description = entity:get_vendor_description()
  local cached = entity.vendor_description_lines

  if cached and cached.text == description and cached.width == width and cached.font == font then
    return cached.lines
  end

  local lines = description != '' and util.wrap_text(description, font, width, 0) or {}

  entity.vendor_description_lines = { text = description, width = width, font = font, lines = lines }

  return lines
end

--- Draws the name and the description of the vendor that the local player is looking at
-- above its head. It is drawn from here rather than as an ordinary target ID, because those
-- are hidden when the feet of the entity are out of sight, as they are behind a counter.
function Vendors:HUDDrawTargetID()
  local client = PLAYER

  if !IsValid(client) or !client:Alive() then return end

  local trace = client:GetEyeTraceNoCursor()
  local entity = trace.Entity

  if !self:is_vendor(entity) then return end

  local distance = EyePos():Distance(trace.HitPos)

  if distance > target_distance then return end

  local head_pos = entity:GetPos()

  head_pos.z += entity:OBBMaxs().z + 10

  local screen_pos = head_pos:ToScreen()

  if !screen_pos.visible then return end

  local alpha = 255 - 255 * (distance / target_distance)
  local name = entity:get_vendor_name()
  local name_font = Theme.get_font('tooltip_large')
  local desc_font = Theme.get_font('tooltip_normal')
  local name_w, name_h = text_size(name, name_font)
  local lines = get_description_lines(entity, desc_font, ScrW() * 0.33)
  local line_count = #lines
  local height = name_h

  for i = 1, line_count do
    local _line_w, line_h = text_size(lines[i], desc_font)

    height += line_h
  end

  local x, y = screen_pos.x, screen_pos.y - height
  local outline_color = color_black:alpha(alpha)
  local text_color = color_white:alpha(alpha)

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

  y += name_h

  for i = 1, line_count do
    local line = lines[i]
    local line_w, line_h = text_size(line, desc_font)

    draw.SimpleTextOutlined(line, desc_font, x - line_w * 0.5, y, text_color, nil, nil, 1, outline_color)

    y += line_h
  end
end

--- Asks the server for fresh prices shortly after an inventory of the local player has
-- changed while the trade panel is open, unless the server sends them first.
-- @param inventory [Inventory the inventory that has been received]
function Vendors:InventorySynced(inventory)
  if !IsValid(self.trade_panel) or inventory.owner != PLAYER then return end

  timer.Create('fl_vendor_refresh', refresh_delay, 1, function()
    local panel = Vendors.trade_panel

    if IsValid(panel) and IsValid(panel:get_vendor()) then
      Cable.send('fl_vendor_refresh', panel:get_vendor())
    end
  end)
end

--- Updates the line about money of the trade panel when the money of the local player
-- changes.
-- @param entity [Entity the entity whose variable has changed]
-- @param key [String variable name]
function Vendors:NetVarChanged(entity, key)
  if entity == PLAYER and key == 'fl_currencies' and IsValid(self.trade_panel) then
    self.trade_panel:refresh_money()
  end
end

--- Translates the line about money of the trade panel again when the language changes.
function Vendors:LanguageChanged()
  if IsValid(self.trade_panel) then
    self.trade_panel:refresh_money()
  end
end
