--- Area Display announces the text areas of the map to the players who walk into them.
-- It takes over the `textarea` area type of the Areas API: while this plugin is loaded,
-- entering a text area shows its text as an area notice instead of the plain text the Areas
-- API draws on its own, so a player never gets both. Entering or leaving a text area runs
-- the `PlayerEnteredTextArea` and `PlayerLeftTextArea` hooks.
--
-- Staff create text areas with the Text Area mode of the Area Tool, which this plugin
-- replaces with one that also has a display style and a one-time switch. Right clicking
-- inside of an existing text area applies both to it. An area keeps them in its `style` and
-- `once` fields, next to its `text`.
--
-- A notice is drawn in a display style. Three come with the plugin: 'fade', a title that
-- fades in and out and is the default; 'typewriter', text that is typed out letter by letter
-- with a quiet sound; and 'cinematic', a caption between the letterbox bars of the
-- Cinematics plugin, which falls back to 'fade' when that plugin is not loaded. More are
-- added with `AreaDisplay:register_style`.
--
-- The same area is not announced again until the 'area_display_cooldown' config has passed.
-- A one-time area is shown to a player only once: the server remembers it in the data table
-- of the player (`Player:set_player_data`, under 'seen_areas'). Players turn the notices off
-- with the 'area_display' client setting when the Settings plugin is loaded.
--
-- The `AdjustAreaDisplay` hook lets other plugins change a notice before it is shown, for
-- example to put the in-game time into its text. The server shows a notice of its own with
-- `AreaDisplay:show`, client code with `AreaDisplay:add`.
--
-- The look comes from the theme, which the plugin fills in from its `OnThemeLoaded` handler:
-- the 'area_display_duration', 'area_display_fade_time', 'area_display_type_interval' and
-- 'area_display_type_volume' options, the 'area_display_text' color, the 'area_display_type'
-- sound and the 'area_display_title' and 'area_display_typewriter' fonts.
-- @module [AreaDisplay]

PLUGIN:set_global('AreaDisplay')

local styles = AreaDisplay.styles or {}

AreaDisplay.styles = styles
AreaDisplay.default_style = 'fade'
AreaDisplay.area_type = 'textarea'

--- Registers a display style: a way of putting an area notice on the screen. Register it
-- from shared code, so that the server accepts it from the Area Tool. Registering an ID again
-- replaces the style.
-- ```
-- local style = { name = 'my_schema.area_styles.corner' }
--
-- if CLIENT then
--   function style:draw(display, alpha, scrw, scrh, offset)
--     local font = Theme.get_font('text_normal')
--     local color = Theme.get_color('text'):alpha(alpha)
--
--     draw.SimpleText(display.text, font, 32, scrh - 64 - offset, color)
--
--     return util.font_size(font)
--   end
-- end
--
-- AreaDisplay:register_style('corner', style)
-- ```
-- @param id [String unique style ID, stored in the `style` field of an area]
-- @param data [Map style definition: name (String phrase or text shown in the Area Tool, the
--   ID by default) and the optional clientside functions is_available(style) (return false
--   to have the default style used instead), start(style, display) (called when a notice is
--   about to be shown, may change its `fade_in`, `hold` and `fade_out` times; return false if
--   the style shows the notice by other means and nothing is to be drawn) and
--   draw(style, display, alpha, scrw, scrh, offset) (draws the notice at the given opacity
--   from 0 to 255 and returns the height it took, which is the offset of the next notice of
--   the same style)]
-- @return [Map the registered style, or nil if the arguments are not valid]
function AreaDisplay:register_style(id, data)
  if !isstring(id) or !istable(data) then return end

  data.id = id
  data.name = data.name or id

  styles[id] = data

  return data
end

--- Returns a display style.
-- @param id [String style ID]
-- @return [Map the style, or nil if it is not registered]
function AreaDisplay:find_style(id)
  return styles[id]
end

--- Returns every registered display style.
-- @return [Map styles keyed by style ID]
function AreaDisplay:get_styles()
  return styles
end

--- Turns a value into the ID of a registered display style.
-- @param id [Any style ID to check]
-- @return [String the ID if such a style is registered, otherwise the ID of the default style]
function AreaDisplay:get_style_id(id)
  if isstring(id) and styles[id] then
    return id
  end

  return self.default_style
end

--- Finds a text area by its ID.
-- @param id [String area ID]
-- @return [Map the area, or nil if there is no text area with that ID]
function AreaDisplay:find_text_area(id)
  if !isstring(id) then return end

  local areas = Areas.all()
  local area = areas[id]

  if area == nil then
    local number_id = tonumber(id)

    if number_id then
      area = areas[number_id]
    end
  end

  if istable(area) and area.type == self.area_type then
    return area
  end
end

--- Finds every text area that a position is inside of.
-- @param pos [Vector position to check, 16 units are added to its height as the Areas API
--   does for players]
-- @return [List<Map> the text areas that contain the position, empty if there are none]
function AreaDisplay:find_text_areas_at(pos)
  local found = {}
  local height = pos.z + 16
  local area_type = self.area_type

  for id, area in pairs(Areas.all()) do
    if istable(area) and area.type == area_type and istable(area.polys) then
      for k, poly in ipairs(area.polys) do
        if height > poly[1].z and height < area.maxh and util.vector_in_poly(pos, poly) then
          found[#found + 1] = area

          break
        end
      end
    end
  end

  return found
end

--- Finds the text area that a position is inside of.
-- @param pos [Vector position to check, 16 units are added to its height as the Areas API
--   does for players]
-- @return [Map the first text area that contains the position, or nil if there is none]
-- @see [AreaDisplay:find_text_areas_at]
function AreaDisplay:find_text_area_at(pos)
  return self:find_text_areas_at(pos)[1]
end

--- Builds the Text Area mode of the Area Tool that this plugin adds: a text area mode that
-- also sets the display style of the area and whether it is shown to a player only once.
-- @return [Map the mode definition, ready for mode_list:Add]
local function build_tool_mode()
  local mode = {}
  mode.title = t'tool.area_display.title'
  mode.area_type = AreaDisplay.area_type
  mode.ClientConVar = {
    height = '512',
    text = 'Sample Text',
    style = AreaDisplay.default_style,
    once = '0'
  }

  --- Starts a text area if needed and adds the aimed position as a vertex. A new area gets
  -- the text, the display style and the one-time switch chosen in the tool; if an area with
  -- the ID of the text exists already, the vertex starts another polygon of that area, which
  -- keeps its style and switch.
  -- @param tool [Tool the area tool]
  -- @param trace [Map trace result of the tool owner's aim]
  -- @return [Boolean true if a vertex was added, false if the area text is invalid]
  function mode:OnLeftClick(tool, trace)
    local text = tostring(tool:GetClientInfo('text'))
    local id = text:to_id()

    if !id or id == '' then return false end

    if !tool.area then
      local is_new = Areas.all()[id] == nil
      local area = Areas.create(id, tonumber(tool:GetClientNumber('height')), { type = self.area_type })

      area.text = text

      if is_new then
        area.style = AreaDisplay:get_style_id(tool:GetClientInfo('style'))
        area.once = tool:GetClientNumber('once') == 1 or nil
        area.created_at = os.time()
      end

      tool.area = area
    end

    tool.area:add_vertex(trace.HitPos)

    return true
  end

  --- Registers the text area being built. With no area being built, applies the display
  -- style and the one-time switch chosen in the tool to the text area that was hit.
  -- @param tool [Tool the area tool]
  -- @param trace [Map trace result of the tool owner's aim]
  -- @return [Boolean true if an area was registered or updated, false if there is no text
  --   area at the aimed position]
  function mode:OnRightClick(tool, trace)
    if tool.area then
      tool.area:register()
      tool.area = nil

      return true
    end

    local area = AreaDisplay:find_text_area_at(trace.HitPos)

    if !area then return false end

    if SERVER then
      area.style = AreaDisplay:get_style_id(tool:GetClientInfo('style'))
      area.once = tool:GetClientNumber('once') == 1 or nil

      Areas.register(area.id, area)

      tool:GetOwner():notify('notification.area_display.updated', { text = tostring(area.text) })
    end

    return true
  end

  --- Adds the mode's text, height, display style and one-time controls to the tool's
  -- settings panel.
  -- @param panel [Panel the tool's control panel]
  function mode:BuildCPanel(panel)
    local options = {}

    for id, style in pairs(AreaDisplay:get_styles()) do
      options[t(style.name)] = { area_style = id }
    end

    local current_style = AreaDisplay:find_style(AreaDisplay:get_style_id(PLAYER:GetInfo('area_style')))
    local current_name = current_style and t(current_style.name) or ''

    panel:AddControl('Header', { Description = t'tool.area_display.desc' })
    panel:AddControl('TextBox', { Label = t'tool.area_display.text', Command = 'area_text' })
    panel:AddControl('Slider', {
      Label = t'tool.area_display.height',
      Command = 'area_height',
      Type = 'Float',
      Min = -2048,
      Max = 2048
    })
    panel:AddControl('Label', { Text = t'tool.area_display.style' })

    local style_control = panel:AddControl('ComboBox', {
      MenuButton = 1,
      Folder = 'areadisplay',
      Options = options,
      CVars = { 'area_style' }
    })
    style_control.Button:SetVisible(false)
    style_control.DropDown:SetValue(current_name)

    panel:AddControl('CheckBox', { Label = t'tool.area_display.once', Command = 'area_once' })
  end

  return mode
end

--- Replaces the Text Area mode of the Area Tool with the one of this plugin (see
-- `build_tool_mode`). The mode is passed through mode_list:Add, which fills in its defaults
-- and merges its convars into the tool, and then takes the place of the first Text Area mode
-- in the list; any other Text Area mode is removed, so that a code refresh does not leave
-- more than one behind. The mode stays at the end of the list if the Areas API has not added
-- its own.
-- @param mode_list [Map the Area.tool_modes table; modes are added with mode_list:Add]
function AreaDisplay:AddAreaToolModes(mode_list)
  mode_list:Add(build_tool_mode())

  local mode = table.remove(mode_list)
  local index

  for k = 1, #mode_list do
    if mode_list[k].area_type == self.area_type then
      index = k

      break
    end
  end

  if !index then
    table.insert(mode_list, mode)

    return
  end

  mode_list[index] = mode

  for k = #mode_list, index + 1, -1 do
    if mode_list[k].area_type == self.area_type then
      table.remove(mode_list, k)
    end
  end
end

Areas.set_callback(AreaDisplay.area_type, function(actor, area, has_entered, pos, cur_time)
  if has_entered then
    --- Called when a player enters a text area. Runs on the server and on the client of that
    -- player. The client-side handler of Area Display shows the notice of the area. Do not
    -- return anything from a handler, or the plugins after it are not told.
    -- @param actor [Player The player who has entered the area]
    -- @param area [Map The area table, with the `text`, `style` and `once` fields]
    -- @param cur_time [Number CurTime() of the check]
    Plugin.call('PlayerEnteredTextArea', actor, area, cur_time)
  else
    --- Called when a player leaves a text area. Runs on the server and on the client of that
    -- player. Do not return anything from a handler, or the plugins after it are not told.
    -- @param actor [Player The player who has left the area]
    -- @param area [Map The area table, with the `text`, `style` and `once` fields]
    -- @param cur_time [Number CurTime() of the check]
    Plugin.call('PlayerLeftTextArea', actor, area, cur_time)
  end
end)

require_relative 'sh_styles'
require_relative 'cl_plugin'
require_relative 'cl_hooks'
require_relative 'sv_plugin'
