--- Toolgun Render Fix replaces the HUD drawing of the tool gun, so that the name and the
-- description of Flux tools are translated by the Flux language system instead of the
-- engine's.

local draw_text_shadow = draw.TextShadow
local draw_textured_quad = draw.TexturedQuad
local set_draw_color = surface.SetDrawColor
local set_material = surface.SetMaterial
local draw_textured_rect = surface.DrawTexturedRect

PLUGIN:set_name('Toolgun Render Fix')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Fixes toolgun help rendering incorrectly with Flux phrases.')

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

    -- Don't draw help for a nonexistent tool!
    if !tool_object then return end

    tool_object:DrawHUD()

    if !gmod_drawhelp:GetBool() then return end

    -- This could probably all suck less than it already does

    local x, y = 50, 40
    local w, h = 0, 0
    local is_flux = tool_object.is_flux_tool

    local text_table = {}
    local quad_table = {}

    quad_table.texture = self.Gradient
    quad_table.color = background_color

    quad_table.x = 0
    quad_table.y = y - 8
    quad_table.w = 600
    quad_table.h = self.ToolNameHeight - (y - 8)
    draw_textured_quad(quad_table)

    text_table.font = 'GModToolName'
    text_table.color = title_color
    text_table.pos = { x, y }
    text_table.text = !is_flux and '#tool.'..mode..'.name' or t('tool.'..mode..'.name')
    w, h = draw_text_shadow(text_table, 2)
    y = y + h

    text_table.font = 'GModToolSubtitle'
    text_table.pos = { x, y }
    text_table.text = !is_flux and '#tool.'..mode..'.desc' or t('tool.'..mode..'.desc')
    w, h = draw_text_shadow(text_table, 1)
    y = y + h + 8

    self.ToolNameHeight = y

    quad_table.y = y
    quad_table.h = self.InfoBoxHeight
    local alpha = math.Clamp(255 + (tool_object.LastMessage - CurTime()) * 800, 10, 255)
    quad_table.color = Color(alpha, alpha, alpha, 230)
    draw_textured_quad(quad_table)

    y = y + 4

    text_table.font = 'GModToolHelp'

    if !tool_object.Information then
      text_table.pos = { x + self.InfoBoxHeight, y }
      text_table.text = tool_object:GetHelpText()
      w, h = draw_text_shadow(text_table, 1)

      set_draw_color(255, 255, 255, 255)
      surface.SetTexture(self.InfoIcon)
      draw_textured_rect(x + 1, y + 1, h - 3, h - 3)

      self.InfoBoxHeight = h + 8

      return
    end

    local h2 = 0
    local icons = self.Icons or {}

    self.Icons = icons

    for k, v in pairs(tool_object.Information) do
      if isstring(v) then v = { name = v } end

      local name = v.name

      if !name then continue end
      if v.stage and v.stage != self:GetStage() then continue end
      if v.op and v.op != tool_object:GetOperation() then continue end

      if name == 'info' then
        text_table.text = tool_object:GetHelpText()
      else
        text_table.text = '#tool.'..mode..'.'..name
      end

      text_table.pos = { x + 21, y + h2 }

      w, h = draw_text_shadow(text_table, 1)

      if !v.icon then
        if name:start_with('info') then v.icon = 'gui/info' end
        if name:start_with('left') then v.icon = 'gui/lmb.png' end
        if name:start_with('right') then v.icon = 'gui/rmb.png' end
        if name:start_with('reload') then v.icon = 'gui/r.png' end
        if name:start_with('use') then v.icon = 'gui/e.png' end
      end

      if !v.icon2 and !name:start_with('use') and name:end_with('use') then v.icon2 = 'gui/e.png' end

      local icon, icon2 = v.icon, v.icon2
      local icon_material = icon and icons[icon]

      if icon and !icon_material then
        icon_material = Material(icon)
        icons[icon] = icon_material
      end

      local icon2_material = icon2 and icons[icon2]

      if icon2 and !icon2_material then
        icon2_material = Material(icon2)
        icons[icon2] = icon2_material
      end

      if icon_material and !icon_material:IsError() then
        set_draw_color(255, 255, 255, 255)
        set_material(icon_material)
        draw_textured_rect(x, y + h2, 16, 16)
      end

      if icon2_material and !icon2_material:IsError() then
        set_draw_color(255, 255, 255, 255)
        set_material(icon2_material)
        draw_textured_rect(x - 25, y + h2, 16, 16)

        draw.SimpleText('+', 'default', x - 8, y + h2 + 2, color_white)
      end

      h2 = h2 + h
    end

    self.InfoBoxHeight = h2 + 8
  end
end
