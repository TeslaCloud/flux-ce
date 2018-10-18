function flMapscene:RenderScreenspaceEffects()
  if IsValid(fl.client) and fl.client:Alive() and IsValid(fl.client:GetActiveWeapon()) and fl.client:GetActiveWeapon():GetClass() == 'gmod_tool'
   and fl.client:GetTool() and fl.client:GetTool().Name == 'Mapscene tool' and !IsValid(fl.intro_panel) then
    for k, v in pairs(self.points) do
      local start_pos = v.pos:ToScreen()

      cam.Start3D()
        render.SetMaterial(Material('sprites/combineball_glow_blue_1'))
        render.DrawSphere(v.pos, 5, 10, 10, Color('lightblue'))
        render.DrawLine(v.pos, v.pos + v.ang:Forward() * 20, Color('lightblue'))
      cam.End3D()

      draw.SimpleText('Mapscene #'..k, theme.get_font('text_small'), start_pos.x, start_pos.y, Color('lightblue'))
    end
  end
end

local view = {}

function flMapscene:CalcView(player, origin, angles, fov)
  if IsValid(fl.intro_panel) then
    local point = self.points[1]

    if point then
      view.origin = point.pos
      view.angles = point.ang

      return view
    end
  end
end
