PLUGIN:set_name('Toolgun Render Fix')
PLUGIN:set_author('Mr. Meow')
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

    local TextTable = {}
    local QuadTable = {}

    QuadTable.texture = self.Gradient
    QuadTable.color = Color(10, 10, 10, 180)

    QuadTable.x = 0
    QuadTable.y = y - 8
    QuadTable.w = 600
    QuadTable.h = self.ToolNameHeight - (y - 8)
    draw.TexturedQuad(QuadTable)

    TextTable.font = 'GModToolName'
    TextTable.color = Color(240, 240, 240, 255)
    TextTable.pos = { x, y }
    TextTable.text = !is_flux and '#tool.'..mode..'.name' or t('tool.'..mode..'.name')
    w, h = draw.TextShadow(TextTable, 2)
    y = y + h

    TextTable.font = 'GModToolSubtitle'
    TextTable.pos = { x, y }
    TextTable.text = !is_flux and '#tool.'..mode..'.desc' or t('tool.'..mode..'.desc')
    w, h = draw.TextShadow(TextTable, 1)
    y = y + h + 8

    self.ToolNameHeight = y

    QuadTable.y = y
    QuadTable.h = self.InfoBoxHeight
    local alpha = math.Clamp(255 + (tool_object.LastMessage - CurTime()) * 800, 10, 255)
    QuadTable.color = Color(alpha, alpha, alpha, 230)
    draw.TexturedQuad(QuadTable)

    y = y + 4

    TextTable.font = 'GModToolHelp'

    if (!tool_object.Information) then
      TextTable.pos = { x + self.InfoBoxHeight, y }
      TextTable.text = tool_object:GetHelpText()
      w, h = draw.TextShadow(TextTable, 1)

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

      local txt = '#tool.' .. GetConVarString('gmod_toolmode') .. '.' .. v.name
      if (v.name == 'info') then
        txt = tool_object:GetHelpText()
      end

      TextTable.text = txt
      TextTable.pos = { x + 21, y + h2 }

      w, h = draw.TextShadow(TextTable, 1)

      if (!v.icon) then
        if (v.name:StartWith('info')) then v.icon = 'gui/info' end
        if (v.name:StartWith('left')) then v.icon = 'gui/lmb.png' end
        if (v.name:StartWith('right')) then v.icon = 'gui/rmb.png' end
        if (v.name:StartWith('reload')) then v.icon = 'gui/r.png' end
        if (v.name:StartWith('use')) then v.icon = 'gui/e.png' end
      end
      if (!v.icon2 and !v.name:StartWith('use') and v.name:EndsWith('use')) then v.icon2 = 'gui/e.png' end

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
