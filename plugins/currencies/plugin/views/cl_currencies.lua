local PANEL = {}

function PANEL:Init()
  self.title = t'ui.currency.title'
end

function PANEL:Paint(w, h)
  DisableClipping(true)
    draw.RoundedBox(0, -4, -4, w + 8, h + 8, Color(50, 50, 50, 100))
  DisableClipping(false)
end

function PANEL:PaintOver(w, h)
  if self.title then
    local text = t(self.title)
    local font = Theme.get_font('main_menu_normal_large')
    local text_w, text_h = util.text_size(text, font)

    DisableClipping(true)
      draw.textured_rect(Theme.get_material('gradient_down'), -4, -text_h - 4, text_w + 8, text_h, Color(50, 50, 50, 100))
      draw.SimpleText(text, font, 0, -text_h - 4, color_white:alpha(150))
    DisableClipping(false)
  end
end

function PANEL:SizeToContents()
  self:SetSize(self.max_w + math.scale_x(4), self.max_h + math.scale(4))
end

function PANEL:set_entity(entity)
  self.entity = entity
end

function PANEL:rebuild()
  self.max_w = 0
  self.max_h = 0
  self:Clear()

  for k, v in pairs(Currencies.all()) do
    local amount = self.entity:get_money(k) or 0

    if !v.hidden or v.hidden and amount > 0 then
      local line = vgui.create('DPanel', self)
      line:SetPaintBackground(false)

      local label = vgui.create('DLabel', line)
      label:SetText(t(v.name)..': '..amount..' '..(v.symbol or ''))
      label:SetFont(Theme.get_font('main_menu_normal'))
      label:SetTextColor(Color('white'))
      label:SizeToContents()
      label:Dock(FILL)

      local button_size = label:GetTall()
      local w = label:GetWide()

      if amount > 0 then
        if self.entity == PLAYER then
          local give_button = vgui.create('fl_button', line)
          give_button:SetSize(button_size, button_size)
          give_button:SetDrawBackground(false)
          give_button:SetTooltip(t'ui.currency.give.title')
          give_button:set_icon('fa-hand-holding-usd')
          give_button:set_icon_size(button_size)
          give_button:Dock(RIGHT)
          give_button.DoClick = function(btn)
            local target = PLAYER:GetEyeTraceNoCursor().Entity

            Derma_StringRequest(t'ui.currency.give.title', t('ui.currency.give.message', { currency = t(v.name) }), '', function(text)
              local value = tonumber(text)

              if value and value > 0 then
                Cable.send('fl_currency_give', value, k, target)
              else
                PLAYER:notify('error.invalid_amount')
              end
            end)
          end

          w = w + give_button:GetWide()

          local drop_button = vgui.create('fl_button', line)
          drop_button:SetSize(button_size, button_size)
          drop_button:SetDrawBackground(false)
          drop_button:SetTooltip(t'ui.currency.drop.title')
          drop_button:set_icon('coins')
          drop_button:set_icon_size(button_size)
          drop_button:Dock(RIGHT)
          drop_button.DoClick = function(btn)
            Derma_StringRequest(t'ui.currency.drop.title', t('ui.currency.drop.message', { currency = t(v.name) }), '', function(text)
              local value = tonumber(text)

              if value and value > 0 then
                Cable.send('fl_currency_drop', value, k)
              else
                PLAYER:notify('error.invalid_amount')
              end
            end)
          end

          w = w + drop_button:GetWide()
        else
          local take_button = vgui.create('fl_button', line)
          take_button:SetSize(button_size, button_size)
          take_button:SetDrawBackground(false)
          take_button:SetTooltip(t'ui.currency.take.title')
          take_button:set_icon('angle-double-left')
          take_button:set_icon_size(button_size)
          take_button:Dock(RIGHT)
          take_button.DoClick = function(btn)
            Derma_StringRequest(t'ui.currency.take.title', t('ui.currency.take.message', { currency = t(v.name) }), amount, function(text)
              local value = tonumber(text)

              if value and value > 0 then
                Cable.send('fl_currency_take', self.entity, value, k)
              else
                PLAYER:notify('error.invalid_amount')
              end
            end)
          end

          w = w + take_button:GetWide()
        end
      end

      line:SetSize(w, label:GetTall())
      line:Dock(TOP)

      if line:GetWide() > self.max_w then
        self.max_w = line:GetWide()
      end

      self.max_h = self.max_h + line:GetTall()
    end
  end
end

vgui.Register('fl_currencies', PANEL, 'fl_base_panel')
