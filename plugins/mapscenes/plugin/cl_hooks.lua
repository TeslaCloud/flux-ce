--- Client hooks of the Mapscenes plugin: the camera that shows the mapscene points, and the
-- markers drawn for the points while the Mapscene tool is held.

local config_get = Config.get
local marker_material = Material('sprites/combineball_glow_blue_1')
local marker_color = Color('lightblue')

--- Draws a marker, a direction line and a label for every mapscene point while the local
-- player holds the mapscene tool and has the 'mapscenes' permission.
function Mapscenes:RenderScreenspaceEffects()
  local client = PLAYER

  if !IsValid(client) or !client:Alive() then return end

  local weapon = client:GetActiveWeapon()

  if !IsValid(weapon) or weapon:GetClass() != 'gmod_tool' then return end

  local tool = client:GetTool()

  if !tool or tool.Name != 'Mapscene tool' or IsValid(Flux.intro_panel) or !can('mapscenes') then return end

  local points = self.points
  local font = Theme.get_font('text_small')
  local title = t'ui.mapscene.title'..' #'

  for k = 1, #points do
    local v = points[k]
    local pos = v.pos
    local start_pos = pos:ToScreen()

    cam.Start3D()
      render.SetMaterial(marker_material)
      render.DrawSphere(pos, 5, 10, 10, marker_color)
      render.DrawLine(pos, pos + v.ang:Forward() * 20, marker_color)
    cam.End3D()

    draw.SimpleText(title..k, font, start_pos.x, start_pos.y, marker_color)
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
    local points = self.points
    local count = #points

    if count > 0 then
      local cur_time = CurTime()
      local animated = config_get('mapscenes_animated')

      self.scene = self.scene or 1

      if !animated and count > 1 then
        self.next_scene = self.next_scene or cur_time + config_get('mapscenes_speed')

        if self.next_scene <= cur_time then
          PLAYER:ScreenFade(SCREENFADE.IN, Color(0, 0, 0), 2, 0)
          self.scene = self.scene + 1
          self.next_scene = cur_time + config_get('mapscenes_speed')

          if self.scene > count then
            self.scene = 1
          end
        end
      end

      local point = points[self.scene]

      if point then
        self.pos = point.pos
        self.ang = point.ang

        if animated and count > 1 then
          local next_point = points[self.scene < count and self.scene + 1 or 1]

          self.start_time = self.start_time or cur_time
          self.end_time = self.end_time or cur_time + config_get('mapscenes_speed')

          local fraction = math.min(1, math.TimeFraction(self.start_time, self.end_time, cur_time))

          self.pos = LerpVector(fraction, point.pos, next_point.pos)
          self.ang = LerpAngle(fraction, point.ang, next_point.ang)

          if self.pos:DistToSqr(next_point.pos) < 1 then
            self.scene = self.scene + 1
            self.start_time = nil
            self.end_time = nil

            if self.scene > count then
              self.scene = 1
            end

            point = points[self.scene]

            self.pos = point.pos
            self.ang = point.ang
          end
        else
          local rotate_speed = config_get('mapscenes_rotate_speed')

          if rotate_speed > 0 then
            self.angle_offset = self.angle_offset or Angle(0, 0, 0)
            self.angle_offset.y = self.angle_offset.y + rotate_speed
            self.ang = self.ang + self.angle_offset
          end
        end

        view.origin = self.pos
        view.angles = self.ang

        return view
      end
    end
  end
end
