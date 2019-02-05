PLUGIN:set_name('Toolgun Render Fix')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Fixes toolgun help rendering incorrectly with Flux phrases.')

function PLUGIN:FLInitPostEntity()
  local toolgun = weapons.GetStored 'gmod_tool'
  local gmod_drawhelp = CreateClientConVar('gmod_drawhelp', '1', true, false)
  local gmod_toolmode = CreateClientConVar('gmod_toolmode', 'rope', true, true)

  function toolgun:DrawHUD()
    local mode = gmod_toolmode:GetString()
    local tool_object = self:GetToolObject()

    -- Don't draw help for a nonexistent tool!
    if !tool_object then return end

    tool_object:DrawHUD()

    if (!gmod_drawhelp:GetBool()) then return end

    -- This could probably all suck less than it already does

    local x, y = 50, 40
    local w, h = 0, 0
    local is_flux = tool_object.is_flux_tool

    local text_table = {}
    local quad_table = {}

    quad_table.texture = self.Gradient
    quad_table.color = Color(10, 10, 10, 180)

    quad_table.x = 0
    quad_table.y = y - 8
    quad_table.w = 600
    quad_table.h = self.ToolNameHeight - (y - 8)
    draw.TexturedQuad(quad_table)

    text_table.font = 'GModToolName'
    text_table.color = Color(240, 240, 240, 255)
    text_table.pos = { x, y }
    text_table.text = !is_flux and '#tool.'..mode..'.name' or t('tool.'..mode..'.name')
    w, h = draw.TextShadow(text_table, 2)
    y = y + h

    text_table.font = 'GModToolSubtitle'
    text_table.pos = { x, y }
    text_table.text = !is_flux and '#tool.'..mode..'.desc' or t('tool.'..mode..'.desc')
    w, h = draw.TextShadow(text_table, 1)
    y = y + h + 8

    self.ToolNameHeight = y

    quad_table.y = y
    quad_table.h = self.InfoBoxHeight
    local alpha = math.Clamp(255 + (tool_object.LastMessage - CurTime()) * 800, 10, 255)
    quad_table.color = Color(alpha, alpha, alpha, 230)
    draw.TexturedQuad(quad_table)

    y = y + 4

    text_table.font = 'GModToolHelp'

    if (!tool_object.Information) then
      text_table.pos = { x + self.InfoBoxHeight, y }
      text_table.text = tool_object:GetHelpText()
      w, h = draw.TextShadow(text_table, 1)

      surface.SetDrawColor(255, 255, 255, 255)
      surface.SetTexture(self.InfoIcon)
      surface.DrawTexturedRect(x + 1, y + 1, h - 3, h - 3)

      self.InfoBoxHeight = h + 8

      return
    end

    local h2 = 0

    for k, v in pairs(tool_object.Information) do
      if (isstring(v)) then v = { name = v } end

      if (!v.name) then continue end
      if (v.stage and v.stage != self:GetStage()) then continue end
      if (v.op and v.op != tool_object:GetOperation()) then continue end

      local txt = '#tool.'..GetConVarString('gmod_toolmode')..'.'..v.name
      if (v.name == 'info') then
        txt = tool_object:GetHelpText()
      end

      text_table.text = txt
      text_table.pos = { x + 21, y + h2 }

      w, h = draw.TextShadow(text_table, 1)

      if (!v.icon) then
        if (v.name:starts('info')) then v.icon = 'gui/info' end
        if (v.name:starts('left')) then v.icon = 'gui/lmb.png' end
        if (v.name:starts('right')) then v.icon = 'gui/rmb.png' end
        if (v.name:starts('reload')) then v.icon = 'gui/r.png' end
        if (v.name:starts('use')) then v.icon = 'gui/e.png' end
      end

      if (!v.icon2 and !v.name:starts('use') and v.name:ends('use')) then v.icon2 = 'gui/e.png' end

      self.Icons = self.Icons or {}
      if (v.icon and !self.Icons[v.icon]) then self.Icons[v.icon] = Material(v.icon) end
      if (v.icon2 and !self.Icons[v.icon2]) then self.Icons[v.icon2] = Material(v.icon2) end

      if (v.icon and self.Icons[v.icon] and !self.Icons[v.icon]:IsError()) then
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(self.Icons[v.icon])
        surface.DrawTexturedRect(x, y + h2, 16, 16)
      end

      if (v.icon2 and self.Icons[v.icon2] and !self.Icons[v.icon2]:IsError()) then
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(self.Icons[v.icon2])
        surface.DrawTexturedRect(x - 25, y + h2, 16, 16)

        draw.SimpleText('+', 'default', x - 8, y + h2 + 2, color_white)
      end

      h2 = h2 + h
    end

    self.InfoBoxHeight = h2 + 8
  end
end
