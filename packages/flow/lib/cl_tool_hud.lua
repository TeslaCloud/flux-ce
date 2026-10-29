--- The help box of the tool gun for Flux tools. `Flux.Tool:install_hud` replaces the `DrawHUD`
-- of the tool gun, so that the name, the description and the usage hints of Flux tools
-- (`Tool.is_flux_tool`) are translated by the Flux language system instead of the engine's,
-- and so that the help box is scaled with the screen like the rest of the interface. Other
-- tools keep their engine phrases. `Flux.Tool:create_hud_fonts` creates the scaled fonts of
-- the help box.
-- @module [Flux::Tool]

mod 'Flux::Tool'

const CurTime = CurTime
const math_clamp = math.Clamp
const draw_simple_text = draw.SimpleText
const set_draw_color = surface.SetDrawColor
const set_texture = surface.SetTexture
const set_material = surface.SetMaterial
const draw_textured_rect = surface.DrawTexturedRect
const get_material = util.get_material

const background_color = Color(10, 10, 10, 180)
const title_color = Color(240, 240, 240, 255)
const shadow_color = Color(0, 0, 0, 200)
const info_color = Color(255, 255, 255, 230)

local string_entries = {}

local function draw_shadowed_text(text, font, x, y, color, distance)
  draw_simple_text(text, font, x + distance, y + distance, shadow_color)

  return draw_simple_text(text, font, x, y, color)
end

local function draw_quad(texture, color, x, y, w, h)
  set_texture(texture)
  set_draw_color(color.r, color.g, color.b, color.a)
  draw_textured_rect(x, y, w, h)
end

--- Returns the text of a phrase of a tool: translated by Flux for a Flux tool, the engine
-- phrase otherwise.
-- @param is_flux [Boolean whether the tool is a Flux tool]
-- @param mode [String tool mode]
-- @param name [String phrase name, such as 'name', 'desc' or 'left']
-- @return [String]
local function tool_phrase(is_flux, mode, name)
  return is_flux ? t('tool.'..mode..'.'..name) : '#tool.'..mode..'.'..name
end

--- Returns the icon of a usage hint that does not name one, by the start of its name.
-- @param name [String hint name]
-- @return [String icon path, nil if the name does not start with a known action]
local function default_icon(name)
  if name:start_with('info') then return 'gui/info' end
  if name:start_with('left') then return 'gui/lmb.png' end
  if name:start_with('right') then return 'gui/rmb.png' end
  if name:start_with('reload') then return 'gui/r.png' end
  if name:start_with('use') then return 'gui/e.png' end
end

--- Creates scaled copies of the fonts of the tool gun's help box, which the tool gun creates
-- at fixed sizes for a 1080p screen.
function Flux.Tool:create_hud_fonts()
  local s = DermaScale.scale

  Font.create('fl_tool_name', { font = 'Roboto Bk', size = s(80), weight = 1000 })
  Font.create('fl_tool_subtitle', { font = 'Roboto Bk', size = s(24), weight = 1000 })
  Font.create('fl_tool_help', { font = 'Roboto Bk', size = s(17), weight = 1000 })
end

--- Replaces the `DrawHUD` of the tool gun with one that draws the tool's own HUD and the help
-- box: the name and the description of the tool and its usage hints, with their icons. Called
-- once the weapons have been registered.
function Flux.Tool:install_hud()
  local toolgun = weapons.GetStored('gmod_tool')

  if !toolgun then return end

  local gmod_drawhelp = CreateClientConVar('gmod_drawhelp', '1', true, false)
  local gmod_toolmode = CreateClientConVar('gmod_toolmode', 'rope', true, true)

  --- Draws the tool's own HUD and the help box of the tool gun.
  function toolgun:DrawHUD()
    local mode = gmod_toolmode:GetString()
    local tool_object = self:GetToolObject()

    if !tool_object then return end

    tool_object:DrawHUD()

    if !gmod_drawhelp:GetBool() then return end

    local s = DermaScale.scale
    local x, y = s(50), s(40)
    local is_flux = tool_object.is_flux_tool
    local _w, h

    draw_quad(self.Gradient, background_color, 0, y - s(8), s(600), self.ToolNameHeight - (y - s(8)))

    _w, h = draw_shadowed_text(tool_phrase(is_flux, mode, 'name'), 'fl_tool_name', x, y, title_color, 2)
    y += h

    _w, h = draw_shadowed_text(tool_phrase(is_flux, mode, 'desc'), 'fl_tool_subtitle', x, y, title_color, 1)
    y += h + s(8)

    self.ToolNameHeight = y

    local alpha = math_clamp(255 + (tool_object.LastMessage - CurTime()) * 800, 10, 255)

    info_color.r, info_color.g, info_color.b = alpha, alpha, alpha

    draw_quad(self.Gradient, info_color, 0, y, s(600), self.InfoBoxHeight)

    y += s(4)

    if !tool_object.Information then
      _w, h = draw_shadowed_text(tool_object:GetHelpText(), 'fl_tool_help', x + self.InfoBoxHeight, y, title_color, 1)

      set_draw_color(255, 255, 255, 255)
      set_texture(self.InfoIcon)
      draw_textured_rect(x + s(1), y + s(1), h - s(3), h - s(3))

      self.InfoBoxHeight = h + s(8)

      return
    end

    local stage = self:GetStage()
    local operation = tool_object:GetOperation()
    local h2 = 0

    for _, entry in pairs(tool_object.Information) do
      if isstring(entry) then
        local cached = string_entries[entry]

        if !cached then
          cached = { name = entry }
          string_entries[entry] = cached
        end

        entry = cached
      end

      local name = entry.name

      if !name then continue end
      if entry.stage and entry.stage != stage then continue end
      if entry.op and entry.op != operation then continue end

      local text

      if name == 'info' then
        text = tool_object:GetHelpText()
      else
        text = tool_phrase(is_flux, mode, name)
      end

      _w, h = draw_shadowed_text(text, 'fl_tool_help', x + s(21), y + h2, title_color, 1)

      if !entry.icon then
        entry.icon = default_icon(name)
      end

      if !entry.icon2 and !name:start_with('use') and name:end_with('use') then
        entry.icon2 = 'gui/e.png'
      end

      local icon_material = entry.icon and get_material(entry.icon)
      local icon2_material = entry.icon2 and get_material(entry.icon2)

      if icon_material and !icon_material:IsError() then
        set_draw_color(255, 255, 255, 255)
        set_material(icon_material)
        draw_textured_rect(x, y + h2, s(16), s(16))
      end

      if icon2_material and !icon2_material:IsError() then
        set_draw_color(255, 255, 255, 255)
        set_material(icon2_material)
        draw_textured_rect(x - s(25), y + h2, s(16), s(16))

        draw_simple_text('+', 'Default', x - s(8), y + h2 + s(2), color_white)
      end

      h2 += h
    end

    self.InfoBoxHeight = h2 + s(8)
  end
end
