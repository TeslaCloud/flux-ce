--- The intrinsic elements of Lumen: the lower case tags and the vgui panels they become. Every
-- element has a definition that names its panel class and maps its props onto the panel, and
-- `Lumen.register_element` takes definitions for more. The props that every element takes are
-- handled by `Lumen.apply_props`: `style` (see `Lumen.Style`), `key`, `ref` (a function that
-- receives the panel, or a table from `use_ref` whose `current` is set to it), `visible`,
-- `tooltip`, `on_press` and `on_right_press`.
--
-- The elements and their own props are:
--
-- * `view` (`lumen_view`): a flex container. Children, `on_press`, `on_right_press`.
-- * `spacer` (`lumen_view`): an empty view with `flex = 1`, to push its siblings apart.
-- * `text` (`lumen_text`): a run of text, from its children or its `text` prop.
-- * `button` (`lumen_button`): a button with a text from its children or its `text` prop.
--   `on_press`, `on_right_press`, `disabled`, `active` (drawn as selected), `icon` (a
--   FontAwesome icon ID drawn before the text, when the FontAwesome package is there).
-- * `scroll` (`lumen_scroll`): a flex container that scrolls vertically. Children,
--   `scrollbar` (false hides the bar).
-- * `image` (`DImage`): `src` (material path), `color`, `keep_aspect`.
-- * `input` (`DTextEntry`): `value`, `placeholder`, `multiline`, `numeric`, `on_change`
--   (receives the text), `on_enter` (receives the text).
-- * `checkbox` (`DCheckBoxLabel`): `checked`, `text`, `on_change` (receives the state).
-- * `combo` (`DComboBox`): `options` (a list of strings, or of `{ text = , value = }` tables),
--   `value` (the selected value or text), `placeholder`, `on_change` (receives the value, the
--   text and the index).
-- * `slider` (`DNumSlider`): `value`, `min`, `max`, `decimals`, `text`, `on_change` (receives
--   the number).
-- * `avatar` (`AvatarImage`): `player`, `size` (of the Steam avatar to fetch).
-- * `model` (`DModelPanel`): `model`, `fov`, `cam_pos`, `look_at`, `skin`.
-- @module [Lumen]

local IsValid    = IsValid
local isstring   = isstring
local istable    = istable
local isfunction = isfunction
local isnumber   = isnumber
local isbool     = isbool
local tostring   = tostring
local pcall      = pcall

local elements = Lumen.elements or {}
Lumen.elements = elements

--- Registers an intrinsic element.
-- ```
-- Lumen.register_element('progress', {
--   class = 'DProgress',
--   style = { height = 16 },
--   update = function(panel, props, old_props)
--     panel:SetFraction(props.value or 0)
--   end
-- })
-- ```
-- @param name [String tag name, lower case]
-- @param def [Map the definition: class (String vgui class to create), style (Map default
--   style), children (Boolean whether the element lays out child elements), container
--   (Function(panel) returns the panel that children are created in, the panel itself if
--   missing), mount (Function(panel, props) called once after the panel has been created, the
--   place to wire callbacks), update (Function(panel, props, old_props) called after mounting
--   and on every update, old_props being nil the first time), mouse (Boolean the panel takes
--   mouse input even without press handlers)]
-- @return [Map the definition]
function Lumen.register_element(name, def)
  def.name = name
  elements[name] = def

  return def
end

--- Returns the definition of an intrinsic element.
-- @param name [String tag name]
-- @return [Map the definition, or nil if there is no such element]
function Lumen.find_element(name)
  return elements[name]
end

--- Calls a prop handler safely.
-- @param handler [Function the handler, anything else is ignored]
-- @param ... [Vararg arguments]
local function call(handler, ...)
  if !isfunction(handler) then return end

  local success, err = pcall(handler, ...)

  if !success then
    ErrorNoHalt('Lumen: a handler has failed: '..tostring(err)..'\n')
  end
end

Lumen.call_handler = call

--- Hands a panel to the `ref` prop of its element.
-- @param panel [Panel]
-- @param ref [Function/Map the ref: a function that receives the panel, or a table whose
--   `current` is set]
-- @param value [Panel the panel, or nil when it goes away]
local function assign_ref(ref, value)
  if isfunction(ref) then
    call(ref, value)
  elseif istable(ref) then
    ref.current = value
  end
end

--- Clears the `ref` of an element whose panel is removed.
-- @param panel [Panel]
-- @param props [Map the last props of the element]
function Lumen.release_ref(panel, props)
  if istable(props) and props.ref then
    assign_ref(props.ref, nil)
  end
end

--- Applies the props that every element takes to its panel: the style, the visibility, the
-- tooltip, the ref, mouse input for press handlers, and the position and the size of a panel
-- at the root of a tree, which is docked to fill its container unless its style sizes it.
-- @param panel [Panel]
-- @param props [Map]
-- @param old_props [Map the props of the last update, nil on the first]
-- @param def [Map the definition of the element]
-- @param is_root [Boolean whether the panel is at the top of its tree, outside of any Lumen
--   container]
function Lumen.apply_props(panel, props, old_props, def, is_root)
  local style = Lumen.Style.resolve(props.style, def.style)

  panel.lumen_style = style
  panel.lumen_props = props

  if style.alpha then
    panel:SetAlpha(style.alpha)
  elseif old_props and old_props.style and old_props.style.alpha then
    panel:SetAlpha(255)
  end

  panel:SetVisible(props.visible != false)

  if props.tooltip != (old_props and old_props.tooltip) then
    panel:SetTooltip(props.tooltip or nil)
  end

  if style.cursor then
    panel:SetCursor(style.cursor)
  end

  if def.mouse or props.on_press or props.on_right_press then
    panel:SetMouseInputEnabled(true)
  end

  if props.ref != (old_props and old_props.ref) then
    if old_props then
      assign_ref(old_props.ref, nil)
    end

    assign_ref(props.ref, panel)
  end

  if is_root then
    local parent = panel:GetParent()
    local parent_w, parent_h = ScrW(), ScrH()

    if IsValid(parent) then
      parent_w, parent_h = parent:GetSize()
    end

    local w = Lumen.Style.length(style.width, parent_w)
    local h = Lumen.Style.length(style.height, parent_h)

    if w or h or style.x or style.y then
      panel:Dock(NODOCK)
      panel:SetPos(style.x or 0, style.y or 0)
      panel:SetSize(w or parent_w, h or parent_h)
    else
      panel:Dock(FILL)
    end
  end

  panel:InvalidateLayout()
end

--- Mouse handler for panels that fire `on_press` and `on_right_press` themselves.
-- @param panel [Panel]
-- @param code [Number mouse button]
local function press_handler(panel, code)
  local props = panel.lumen_props

  if !props then return end

  if code == MOUSE_LEFT then
    call(props.on_press, panel)
  elseif code == MOUSE_RIGHT then
    call(props.on_right_press, panel)
  end
end

Lumen.press_handler = press_handler

Lumen.register_element('view', {
  class = 'lumen_view',
  children = true
})

Lumen.register_element('spacer', {
  class = 'lumen_view',
  style = { flex = 1 }
})

Lumen.register_element('text', {
  class = 'lumen_text',
  style = { font = 'text_normal', color = 'text' },
  update = function(panel, props, old_props)
    panel:set_text(Lumen.text_of(props))
  end
})

Lumen.register_element('button', {
  class = 'lumen_button',
  style = {
    font = 'text_normal',
    color = 'text',
    background = 'surface_raised',
    hover_background = 'main_light',
    active_background = 'accent',
    disabled_color = 'text_dim',
    radius = 6,
    padding = { 6, 12 },
    text_align = 'center',
    vertical_align = 'center',
    wrap_text = false,
    cursor = 'hand'
  },
  mouse = true,
  update = function(panel, props, old_props)
    panel:set_text(Lumen.text_of(props))
    panel:set_icon(props.icon)
    panel:set_enabled(props.disabled != true)
    panel:set_active(props.active == true)
  end
})

Lumen.register_element('scroll', {
  class = 'lumen_scroll',
  children = true,
  update = function(panel, props, old_props)
    panel:set_scrollbar_visible(props.scrollbar != false)
  end
})

Lumen.register_element('image', {
  class = 'DImage',
  style = { width = 64, height = 64 },
  update = function(panel, props, old_props)
    if props.src != (old_props and old_props.src) then
      panel:SetImage(props.src or 'vgui/white')
    end

    panel:SetImageColor(Lumen.Style.color(props.color) or color_white)
    panel:SetKeepAspect(props.keep_aspect == true)
  end
})

Lumen.register_element('input', {
  class = 'DTextEntry',
  style = { height = 28, font = 'text_small' },
  mount = function(panel, props)
    panel.OnValueChange = function(entry, value)
      call(entry.lumen_props.on_change, value, entry)
    end

    panel.OnEnter = function(entry)
      call(entry.lumen_props.on_enter, entry:GetValue(), entry)
    end
  end,
  update = function(panel, props, old_props)
    local style = panel.lumen_style

    if style.font then
      panel:SetFont(style.font)
    end

    panel:SetPlaceholderText(props.placeholder or '')
    panel:SetMultiline(props.multiline == true)
    panel:SetNumeric(props.numeric == true)
    panel:SetEnabled(props.disabled != true)

    if props.value != nil and tostring(props.value) != panel:GetValue() then
      panel:SetValue(tostring(props.value))
    end
  end
})

Lumen.register_element('checkbox', {
  class = 'DCheckBoxLabel',
  style = { height = 20, font = 'text_small' },
  mount = function(panel, props)
    panel.OnChange = function(box, value)
      call(box.lumen_props.on_change, value, box)
    end
  end,
  update = function(panel, props, old_props)
    local style = panel.lumen_style

    panel:SetText(props.text or '')

    if style.font then
      panel:SetFont(style.font)
    end

    if style.color then
      panel:SetTextColor(style.color)
    end

    if isbool(props.checked) and props.checked != panel:GetChecked() then
      panel:SetChecked(props.checked)
    end

    panel:SizeToContents()
  end
})

--- Checks whether the options of a combo box have changed.
-- @param options [List]
-- @param old_options [List]
-- @return [Boolean]
local function options_changed(options, old_options)
  if options == old_options then return false end
  if !istable(options) or !istable(old_options) or #options != #old_options then return true end

  for i, option in ipairs(options) do
    local other = old_options[i]

    if istable(option) and istable(other) then
      if option.text != other.text or option.value != other.value then return true end
    elseif option != other then
      return true
    end
  end

  return false
end

Lumen.register_element('combo', {
  class = 'DComboBox',
  style = { height = 28, font = 'text_small' },
  mount = function(panel, props)
    panel.OnSelect = function(combo, index, text, data)
      local value = data

      if value == nil then value = text end

      call(combo.lumen_props.on_change, value, text, index, combo)
    end
  end,
  update = function(panel, props, old_props)
    local style = panel.lumen_style

    if style.font then
      panel:SetFont(style.font)
    end

    if options_changed(props.options, old_props and old_props.options) then
      panel:Clear()

      for k, option in ipairs(props.options or {}) do
        if istable(option) then
          panel:AddChoice(tostring(option.text), option.value)
        else
          panel:AddChoice(tostring(option), option)
        end
      end
    end

    if props.placeholder then
      panel:SetValue(props.placeholder)
    end

    if props.value != nil then
      for k, option in ipairs(props.options or {}) do
        local value = istable(option) and option.value or option
        local text = istable(option) and option.text or option

        if value == props.value or text == props.value then
          if panel:GetSelectedID() != k then
            panel:ChooseOptionID(k)
          end

          break
        end
      end
    end
  end
})

Lumen.register_element('slider', {
  class = 'DNumSlider',
  style = { height = 28 },
  mount = function(panel, props)
    panel.OnValueChanged = function(slider, value)
      if slider.lumen_updating then return end

      call(slider.lumen_props.on_change, value, slider)
    end
  end,
  update = function(panel, props, old_props)
    panel.lumen_updating = true
    panel:SetMin(props.min or 0)
    panel:SetMax(props.max or 1)
    panel:SetDecimals(props.decimals or 0)
    panel:SetText(props.text or '')

    if isnumber(props.value) and props.value != panel:GetValue() then
      panel:SetValue(props.value)
    end

    panel.lumen_updating = false
  end
})

Lumen.register_element('avatar', {
  class = 'AvatarImage',
  style = { width = 64, height = 64 },
  update = function(panel, props, old_props)
    local size = props.size or 64

    if !old_props or props.player != old_props.player or size != (old_props.size or 64) then
      if IsValid(props.player) then
        panel:SetPlayer(props.player, size)
      elseif isstring(props.player) then
        panel:SetSteamID(props.player, size)
      end
    end
  end
})

Lumen.register_element('model', {
  class = 'DModelPanel',
  style = { width = 128, height = 128 },
  update = function(panel, props, old_props)
    if isstring(props.model) and props.model != (old_props and old_props.model) then
      panel:SetModel(props.model)
    end

    if props.fov then panel:SetFOV(props.fov) end
    if props.cam_pos then panel:SetCamPos(props.cam_pos) end
    if props.look_at then panel:SetLookAt(props.look_at) end

    local entity = panel:GetEntity()

    if IsValid(entity) and isnumber(props.skin) then
      entity:SetSkin(props.skin)
    end
  end
})
