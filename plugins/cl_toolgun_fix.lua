--- Toolgun Render Fix replaces the HUD drawing of the tool gun, so that the name and the
-- description of Flux tools are translated by the Flux language system instead of the
-- engine's, and so that the help box is scaled with the screen like the rest of the
-- interface.

local draw_text_shadow = draw.TextShadow
local draw_textured_quad = draw.TexturedQuad
local set_draw_color = surface.SetDrawColor
local set_material = surface.SetMaterial
local draw_textured_rect = surface.DrawTexturedRect

PLUGIN:set_name('Toolgun Render Fix')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Fixes toolgun help rendering incorrectly with Flux phrases.')

--- Creates scaled copies of the fonts of the tool gun's help box, which the tool gun creates
-- at fixed sizes for a 1080p screen.
function PLUGIN:CreateFonts()
  local s = DermaScale.scale

  Font.create('fl_tool_name', { font = 'Roboto Bk', size = s(80), weight = 1000 })
  Font.create('fl_tool_subtitle', { font = 'Roboto Bk', size = s(24), weight = 1000 })
  Font.create('fl_tool_help', { font = 'Roboto Bk', size = s(17), weight = 1000 })
end

--- Replaces the tool gun's DrawHUD with a version that understands Flux phrases.
function PLUGIN:FLInitPostEntity()
  local toolgun = weapons.GetStored 'gmod_tool'
  local gmod_drawhelp = CreateClientConVar('gmod_drawhelp', '1', true, false)
  local gmod_toolmode = CreateClientConVar('gmod_toolmode', 'rope', true, true)
  local background_color = Color(10, 10, 10, 180)
  local title_color = Color(240, 240, 240, 255)

  --- Draws the tool's own HUD and the tool gun help box (name, description, usage hints).
  -- Name and description of Flux tools are translated through the Flux language system.
  function toolgun:DrawHUD()
    local mode = gmod_toolmode:GetString()
    local tool_object = self:GetToolObject()

    if !tool_object then return end

    tool_object:DrawHUD()

    if !gmod_drawhelp:GetBool() then return end

    local s = DermaScale.scale
    local x, y = s(50), s(40)
    local _w, h = 0, 0
    local is_flux = tool_object.is_flux_tool

    local text_table = {}
    local quad_table = {}

    quad_table.texture = self.Gradient
    quad_table.color = background_color

    quad_table.x = 0
    quad_table.y = y - s(8)
    quad_table.w = s(600)
    quad_table.h = self.ToolNameHeight - (y - s(8))
    draw_textured_quad(quad_table)

    text_table.font = 'fl_tool_name'
    text_table.color = title_color
    text_table.pos = { x, y }
    text_table.text = !is_flux and '#tool.'..mode..'.name' or t('tool.'..mode..'.name')
    _w, h = draw_text_shadow(text_table, 2)
    y += h

    text_table.font = 'fl_tool_subtitle'
    text_table.pos = { x, y }
    text_table.text = !is_flux and '#tool.'..mode..'.desc' or t('tool.'..mode..'.desc')
    _w, h = draw_text_shadow(text_table, 1)
    y = y + h + s(8)

    self.ToolNameHeight = y

    quad_table.y = y
    quad_table.h = self.InfoBoxHeight
    local alpha = math.Clamp(255 + (tool_object.LastMessage - CurTime()) * 800, 10, 255)
    quad_table.color = Color(alpha, alpha, alpha, 230)
    draw_textured_quad(quad_table)

    y += s(4)

    text_table.font = 'fl_tool_help'

    if !tool_object.Information then
      text_table.pos = { x + self.InfoBoxHeight, y }
      text_table.text = tool_object:GetHelpText()
      _w, h = draw_text_shadow(text_table, 1)

      set_draw_color(255, 255, 255, 255)
      surface.SetTexture(self.InfoIcon)
      draw_textured_rect(x + s(1), y + s(1), h - s(3), h - s(3))

      self.InfoBoxHeight = h + s(8)

      return
    end

    local h2 = 0

    for _, entry in pairs(tool_object.Information) do
      if isstring(entry) then entry = { name = entry } end

      local name = entry.name

      if !name then continue end
      if entry.stage and entry.stage != self:GetStage() then continue end
      if entry.op and entry.op != tool_object:GetOperation() then continue end

      if name == 'info' then
        text_table.text = tool_object:GetHelpText()
      else
        text_table.text = !is_flux and '#tool.'..mode..'.'..name or t('tool.'..mode..'.'..name)
      end

      text_table.pos = { x + s(21), y + h2 }

      _w, h = draw_text_shadow(text_table, 1)

      if !entry.icon then
        if name:start_with('info') then entry.icon = 'gui/info' end
        if name:start_with('left') then entry.icon = 'gui/lmb.png' end
        if name:start_with('right') then entry.icon = 'gui/rmb.png' end
        if name:start_with('reload') then entry.icon = 'gui/r.png' end
        if name:start_with('use') then entry.icon = 'gui/e.png' end
      end

      if !entry.icon2 and !name:start_with('use') and name:end_with('use') then entry.icon2 = 'gui/e.png' end

      local icon, icon2 = entry.icon, entry.icon2
      local icon_material = icon and util.get_material(icon)
      local icon2_material = icon2 and util.get_material(icon2)

      if icon_material and !icon_material:IsError() then
        set_draw_color(255, 255, 255, 255)
        set_material(icon_material)
        draw_textured_rect(x, y + h2, s(16), s(16))
      end

      if icon2_material and !icon2_material:IsError() then
        set_draw_color(255, 255, 255, 255)
        set_material(icon2_material)
        draw_textured_rect(x - s(25), y + h2, s(16), s(16))

        draw.SimpleText('+', 'Default', x - s(8), y + h2 + s(2), color_white)
      end

      h2 += h
    end

    self.InfoBoxHeight = h2 + s(8)
  end
end
