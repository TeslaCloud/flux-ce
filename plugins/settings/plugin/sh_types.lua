--- Registers the types of settings that come with the Settings plugin: 'boolean', 'number',
-- 'choice' and 'string'. Each of them checks the values of its settings on both realms and
-- creates the control that edits such a setting in the settings menu on the client.

ClientSettings:register_type('boolean', {
  --- Returns the default of a boolean setting that does not define one.
  -- @param setting [Map setting definition]
  -- @return [Boolean false]
  get_default = function(setting)
    return false
  end,
  --- Accepts booleans only.
  -- @param setting [Map setting definition]
  -- @param value [Any value to check]
  -- @return [Boolean the value, or nil if it is not a boolean]
  sanitize = function(setting, value)
    if isbool(value) then
      return value
    end
  end,
  --- Creates a switch that turns the setting on and off. Clientside only.
  -- @param setting [Map setting definition]
  -- @param parent [Panel row of the settings menu to create the control in]
  -- @param value [Boolean current value of the setting]
  -- @param on_change [Function called with the new value when the switch is clicked]
  -- @return [Panel the created fl_button]
  create_control = function(setting, parent, value, on_change)
    local button = vgui.Create('fl_button', parent)
    button.value = value
    button:SetDrawBackground(false)
    button:set_icon(value and 'fa-toggle-on' or 'fa-toggle-off')
    button:set_icon_size(math.scale(24))
    button:set_text_color(value and Theme.get_color('accent_light') or nil)
    button:set_centered(true)
    button.DoClick = function(btn)
      btn.value = !btn.value

      btn:set_icon(btn.value and 'fa-toggle-on' or 'fa-toggle-off')
      btn:set_text_color(btn.value and Theme.get_color('accent_light') or nil)

      on_change(btn.value)
    end

    return button
  end
})

ClientSettings:register_type('number', {
  --- Fills in the range and the precision of a number setting: 0 to 100 without decimals
  -- unless the setting says otherwise.
  -- @param setting [Map setting definition]
  -- @return [Boolean false if the range is not valid, nothing otherwise]
  setup = function(setting)
    setting.min = tonumber(setting.min) or 0
    setting.max = tonumber(setting.max) or 100
    setting.decimals = math.max(math.floor(tonumber(setting.decimals) or 0), 0)

    if setting.min > setting.max then
      return false
    end
  end,
  --- Returns the default of a number setting that does not define one: its minimum.
  -- @param setting [Map setting definition]
  -- @return [Number]
  get_default = function(setting)
    return setting.min
  end,
  --- Accepts numbers, clamped to the range of the setting and rounded to its decimals.
  -- @param setting [Map setting definition]
  -- @param value [Any value to check]
  -- @return [Number the corrected value, or nil if it is not a number]
  sanitize = function(setting, value)
    if !isnumber(value) or value != value then return end

    return math.round(math.clamp(value, setting.min, setting.max), setting.decimals)
  end,
  --- Creates a slider over the range of the setting. Clientside only.
  -- A new DNumSlider holds 0.5 and ignores being set to the value it already holds, so the
  -- slider is told that its value has changed either way; otherwise a setting that is at 0.5
  -- would keep the knob and the text of the slider's initial range of 0 to 1.
  -- @param setting [Map setting definition]
  -- @param parent [Panel row of the settings menu to create the control in]
  -- @param value [Number current value of the setting]
  -- @param on_change [Function called with the new value while the slider is moved]
  -- @return [Panel the created DNumSlider]
  create_control = function(setting, parent, value, on_change)
    local slider = vgui.Create('DNumSlider', parent)
    slider:SetMin(setting.min)
    slider:SetMax(setting.max)
    slider:SetDecimals(setting.decimals)
    slider:SetValue(value)
    slider:ValueChanged(value)
    slider.Label:SetVisible(false)
    slider.TextArea:SetPaintBackground(true)
    slider.PerformLayout = function(pnl)
      pnl.Label:SetWide(0)
    end

    slider.OnValueChanged = function(pnl, new_value)
      on_change(new_value)
    end

    return slider
  end
})

ClientSettings:register_type('choice', {
  --- Turns the choices of the setting into a list of { value, name } tables. A choice that
  -- is given as a plain value is named after that value.
  -- @param setting [Map setting definition]
  -- @return [Boolean false if the setting has no choices, nothing otherwise]
  setup = function(setting)
    if !istable(setting.choices) then
      return false
    end

    local choices = {}

    for k, v in ipairs(setting.choices) do
      if istable(v) then
        if v.value != nil then
          table.insert(choices, { value = v.value, name = tostring(v.name or v.value) })
        end
      else
        table.insert(choices, { value = v, name = tostring(v) })
      end
    end

    if #choices == 0 then
      return false
    end

    setting.choices = choices
  end,
  --- Returns the default of a choice setting that does not define one: its first choice.
  -- @param setting [Map setting definition]
  -- @return [Any value of the first choice]
  get_default = function(setting)
    return setting.choices[1].value
  end,
  --- Accepts the values of the choices of the setting only.
  -- @param setting [Map setting definition]
  -- @param value [Any value to check]
  -- @return [Any the value, or nil if it is not one of the choices]
  sanitize = function(setting, value)
    for k, v in ipairs(setting.choices) do
      if v.value == value then
        return value
      end
    end
  end,
  --- Creates a dropdown that lists the choices of the setting. Clientside only.
  -- The dropdown keeps the position of every choice instead of its value, since DComboBox
  -- drops a value of false.
  -- @param setting [Map setting definition]
  -- @param parent [Panel row of the settings menu to create the control in]
  -- @param value [Any current value of the setting]
  -- @param on_change [Function called with the value of the choice that is picked]
  -- @return [Panel the created DComboBox]
  create_control = function(setting, parent, value, on_change)
    local combo_box = vgui.Create('DComboBox', parent)
    combo_box:SetSortItems(false)

    for k, v in ipairs(setting.choices) do
      combo_box:AddChoice(t(v.name), k, v.value == value)
    end

    combo_box.OnSelect = function(pnl, index, text, data)
      local choice = setting.choices[data]

      if choice then
        on_change(choice.value)
      end
    end

    return combo_box
  end
})

ClientSettings:register_type('string', {
  --- Fills in the maximum length of a string setting: 128 characters unless the setting
  -- says otherwise.
  -- @param setting [Map setting definition]
  setup = function(setting)
    setting.max_length = math.max(math.floor(tonumber(setting.max_length) or 128), 1)
  end,
  --- Returns the default of a string setting that does not define one.
  -- @param setting [Map setting definition]
  -- @return [String an empty string]
  get_default = function(setting)
    return ''
  end,
  --- Accepts strings of valid UTF-8 that are not longer than the setting allows.
  -- @param setting [Map setting definition]
  -- @param value [Any value to check]
  -- @return [String the value, or nil if it is not such a string]
  sanitize = function(setting, value)
    if !isstring(value) then return end

    local length = utf8.len(value)

    if !length or length > setting.max_length then return end

    return value
  end,
  --- Creates a text entry limited to the maximum length of the setting. Clientside only.
  -- @param setting [Map setting definition]
  -- @param parent [Panel row of the settings menu to create the control in]
  -- @param value [String current value of the setting]
  -- @param on_change [Function called with the new text whenever the player edits it]
  -- @return [Panel the created fl_text_entry]
  create_control = function(setting, parent, value, on_change)
    local text_entry = vgui.Create('fl_text_entry', parent)
    text_entry:SetFont(Theme.get_font('text_small'))
    text_entry:set_limit(setting.max_length)
    text_entry:SetValue(value)
    text_entry.OnChange = function(pnl)
      on_change(pnl:GetValue())
    end

    return text_entry
  end
})
