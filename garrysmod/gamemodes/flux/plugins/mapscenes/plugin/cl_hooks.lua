function Mapscenes:RenderScreenspaceEffects()
  if IsValid(fl.client) and fl.client:Alive() and IsValid(fl.client:GetActiveWeapon()) and fl.client:GetActiveWeapon():GetClass() == 'gmod_tool' and
  fl.client:GetTool() and fl.client:GetTool().Name == 'Mapscene tool' and !IsValid(fl.intro_panel) and can('mapscenes') then
    for k, v in pairs(self.points) do
      local start_pos = v.pos:ToScreen()

      cam.Start3D()
        render.SetMaterial(Material('sprites/combineball_glow_blue_1'))
        render.DrawSphere(v.pos, 5, 10, 10, Color('lightblue'))
        render.DrawLine(v.pos, v.pos + v.ang:Forward() * 20, Color('lightblue'))
      cam.End3D()

      draw.SimpleText(t'mapscene.title'..' #'..k, theme.get_font('text_small'), start_pos.x, start_pos.y, Color('lightblue'))
    end
  end
end

local view = {}

function Mapscenes:CalcView(player, origin, angles, fov)
  if hook.run('ShouldMapsceneRender') then
    if #self.points > 0 then
      local cur_time = CurTime()

      self.scene = self.scene or 1

      if !config.get('mapscenes_animated') and #self.points > 1 then
        self.next_scene = self.next_scene or cur_time + config.get('mapscenes_speed')

        if self.next_scene <= cur_time then
          fl.client:ScreenFade(SCREENFADE.IN, Color(0, 0, 0), 2, 0)
          self.scene = self.scene + 1
          self.next_scene = cur_time + config.get('mapscenes_speed')

          if self.scene > #self.points then
            self.scene = 1
          end
        end
      end

      local point = self.points[self.scene]

      if point then
        self.pos = point.pos
        self.ang = point.ang

        if config.get('mapscenes_animated') and #self.points > 1 then
          local next_point = self.points[self.scene < #self.points and self.scene + 1 or 1]

          self.start_time = self.start_time or cur_time
          self.end_time = self.end_time or cur_time + config.get('mapscenes_speed')

          local fraction = math.min(1, math.TimeFraction(self.start_time, self.end_time, cur_time))

          self.pos = LerpVector(fraction, point.pos, next_point.pos)
          self.ang = LerpAngle(fraction, point.ang, next_point.ang)

          if self.pos:Distance(next_point.pos) < 1 then
            self.scene = self.scene + 1
            self.start_time = nil
            self.end_time = nil

            if self.scene > #self.points then
              self.scene = 1
            end

            point = self.points[self.scene]

            self.pos = point.pos
            self.ang = point.ang
          end
        elseif config.get('mapscenes_rotate_speed') > 0 then
          self.angle_offset = self.angle_offset or Angle(0, 0, 0)
          self.angle_offset.y = self.angle_offset.y + config.get('mapscenes_rotate_speed')
          self.ang = self.ang + self.angle_offset
        end

        view.origin = self.pos
        view.angles = self.ang

        return view
      end
    end
  end
end
