--- The money panel (`fl_currencies`): lists how much of every currency an entity holds, with
-- buttons to give or drop the money of the local player, or to take money from another entity
-- such as a container. It is created with `Currencies:create_panel`.

local t = t
local cable_send = Cable.send

local PANEL = {}
PANEL.padding = math.scale(8)

--- Sets the default title of the panel.
function PANEL:Init()
  self.title = t'ui.currency.title'

  self:DockPadding(self.padding, self.padding, self.padding, self.padding)
end

--- Draws the card of the panel.
-- @param w [Number]
-- @param h [Number]
function PANEL:Paint(w, h)
  Theme.hook('PaintSurface', self, w, h)
end

--- Draws the translated title in a tag above the panel.
-- @param w [Number]
-- @param h [Number]
function PANEL:PaintOver(w, h)
  if self.title then
    Theme.hook('PaintSectionTitle', self, t(self.title), w, h)
  end
end

--- Resizes the panel to fit the currency lines created by the last rebuild.
function PANEL:SizeToContents()
  self:SetSize(self.max_w + self.padding * 2 + math.scale_x(4), self.max_h + self.padding * 2)
end

--- Sets the entity whose money the panel shows. Call rebuild afterward to update it.
-- @param entity [Entity]
function PANEL:set_entity(entity)
  self.entity = entity
end

--- Creates one of the icon buttons of a currency line.
-- @param line [Panel the line the button goes into]
-- @param size [Number width and height of the button]
-- @param icon [String FontAwesome icon ID]
-- @param tooltip [String]
-- @param callback [Function called when the button is clicked]
-- @return [Panel the created fl_button]
local function create_line_button(line, size, icon, tooltip, callback)
  local button = vgui.Create('fl_button', line)
  button:SetSize(size, size)
  button:SetDrawBackground(false)
  button:SetTooltip(tooltip)
  button:set_icon(icon)
  button:set_icon_size(size * 0.7)
  button:set_centered(true)
  button:Dock(RIGHT)
  button:DockMargin(math.scale(4), 0, 0, 0)
  button.DoClick = callback

  return button
end

--- Asks the local player for an amount of money and passes it on, or tells them that the
-- amount is not valid.
-- @param title [String translated title of the request]
-- @param message [String translated message of the request]
-- @param default [String/Number text the request starts with]
-- @param callback [Function called with the amount]
local function request_amount(title, message, default, callback)
  Derma_StringRequest(title, message, tostring(default or ''), function(text)
    local value = tonumber(text)

    if value and value > 0 then
      callback(value)
    else
      PLAYER:notify('error.invalid_amount')
    end
  end)
end

--- Recreates a line for every visible currency, with give and drop buttons for the local
-- player's own money or a take button for the money of another entity.
function PANEL:rebuild()
  self.max_w = 0
  self.max_h = 0
  self:Clear()

  local client = PLAYER
  local font = Theme.get_font('text_normal')
  local line_height = math.scale(30)

  for k, v in pairs(Currencies.all()) do
    local amount = self.entity:get_money(k) or 0

    if !v.hidden or v.hidden and amount > 0 then
      local line = vgui.Create('DPanel', self)
      line:SetPaintBackground(false)

      local label = vgui.Create('DLabel', line)
      label:SetText(t(v.name)..': '..amount..' '..(v.symbol or ''))
      label:SetFont(font)
      label:SetTextColor(Theme.get_color('text'))
      label:SizeToContents()
      label:Dock(FILL)

      local button_size = line_height - math.scale(4)
      local w = label:GetWide() + math.scale(16)

      if amount > 0 then
        if self.entity == client then
          create_line_button(line, button_size, 'fa-hand-holding-usd', t'ui.currency.give.title', function()
            local target = client:GetEyeTraceNoCursor().Entity

            request_amount(
              t'ui.currency.give.title',
              t('ui.currency.give.message', { currency = t(v.name) }),
              '',
              function(value)
                cable_send('fl_currency_give', value, k, target)
              end
            )
          end)

          create_line_button(line, button_size, 'coins', t'ui.currency.drop.title', function()
            request_amount(
              t'ui.currency.drop.title',
              t('ui.currency.drop.message', { currency = t(v.name) }),
              '',
              function(value)
                cable_send('fl_currency_drop', value, k)
              end
            )
          end)

          w = w + (button_size + math.scale(4)) * 2
        else
          create_line_button(line, button_size, 'angle-double-left', t'ui.currency.take.title', function()
            request_amount(
              t'ui.currency.take.title',
              t('ui.currency.take.message', { currency = t(v.name) }),
              amount,
              function(value)
                cable_send('fl_currency_take', self.entity, value, k)
              end
            )
          end)

          w = w + button_size + math.scale(4)
        end
      end

      line:SetSize(w, line_height)
      line:Dock(TOP)

      if line:GetWide() > self.max_w then
        self.max_w = line:GetWide()
      end

      self.max_h = self.max_h + line:GetTall()
    end
  end

  self:SizeToContents()
end

vgui.Register('fl_currencies', PANEL, 'fl_base_panel')
