--- Client hooks of the Mapscenes plugin: the camera that shows the mapscene points, and the
-- markers drawn for the points while the Mapscene tool is held.

--- Draws a marker, a direction line and a label for every mapscene point while the local
-- player holds the mapscene tool and has the 'mapscenes' permission.
function Mapscenes:RenderScreenspaceEffects()
  if IsValid(PLAYER) and PLAYER:Alive() and IsValid(PLAYER:GetActiveWeapon())
  and PLAYER:GetActiveWeapon():GetClass() == 'gmod_tool'
  and PLAYER:GetTool() and PLAYER:GetTool().Name == 'Mapscene tool' and !IsValid(Flux.intro_panel)
  and can('mapscenes') then
    for k, v in pairs(self.points) do
      local start_pos = v.pos:ToScreen()

      cam.Start3D()
        render.SetMaterial(Material('sprites/combineball_glow_blue_1'))
        render.DrawSphere(v.pos, 5, 10, 10, Color('lightblue'))
        render.DrawLine(v.pos, v.pos + v.ang:Forward() * 20, Color('lightblue'))
      cam.End3D()

      draw.SimpleText(
        t'ui.mapscene.title'..' #'..k,
        Theme.get_font('text_small'),
        start_pos.x,
        start_pos.y,
        Color('lightblue')
      )
    end
  end
end

local view = {}

--- Replaces the view with the current mapscene point while the ShouldMapsceneRender hook
-- returns true. Depending on the config it cuts to the next point with a fade, glides
-- between the points or slowly rotates the camera.
-- @param client [Player]
-- @param origin [Vector]
-- @param angles [Angle]
-- @param fov [Number]
-- @return [Map view table with origin and angles, or nil if no mapscene is shown]
function Mapscenes:CalcView(client, origin, angles, fov)
  --- Asks whether the mapscene camera should replace the local player's view.
  -- Called on the client on every view calculation. The Characters plugin returns true while
  -- the intro panel or the main menu is open.
  -- @return [Boolean Return true to show the mapscene; the view is left alone otherwise]
  if hook.Run('ShouldMapsceneRender') then
    if #self.points > 0 then
      local cur_time = CurTime()

      self.scene = self.scene or 1

      if !Config.get('mapscenes_animated') and #self.points > 1 then
        self.next_scene = self.next_scene or cur_time + Config.get('mapscenes_speed')

        if self.next_scene <= cur_time then
          PLAYER:ScreenFade(SCREENFADE.IN, Color(0, 0, 0), 2, 0)
          self.scene = self.scene + 1
          self.next_scene = cur_time + Config.get('mapscenes_speed')

          if self.scene > #self.points then
            self.scene = 1
          end
        end
      end

      local point = self.points[self.scene]

      if point then
        self.pos = point.pos
        self.ang = point.ang

        if Config.get('mapscenes_animated') and #self.points > 1 then
          local next_point = self.points[self.scene < #self.points and self.scene + 1 or 1]

          self.start_time = self.start_time or cur_time
          self.end_time = self.end_time or cur_time + Config.get('mapscenes_speed')

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
        elseif Config.get('mapscenes_rotate_speed') > 0 then
          self.angle_offset = self.angle_offset or Angle(0, 0, 0)
          self.angle_offset.y = self.angle_offset.y + Config.get('mapscenes_rotate_speed')
          self.ang = self.ang + self.angle_offset
        end

        view.origin = self.pos
        view.angles = self.ang

        return view
      end
    end
  end
end
