--- Client hooks of the MapScenes plugin: the camera that shows the mapscene points, and the
-- markers drawn for the points while the Mapscene tool is held.

local config_get = Config.get
local marker_material = Material('sprites/combineball_glow_blue_1')
local marker_color = Color('lightblue')
local title_args = {}
local labels = {}
local labeled_points = nil
local labeled_count = 0

--- Draws a marker, a direction line and a label for every mapscene point while the local
-- player holds the mapscene tool and has the 'manage_map_scenes' permission. The labels are
-- translated again only when the points change.
function MapScenes:RenderScreenspaceEffects()
  local client = PLAYER

  if !IsValid(client) or !client:Alive() then return end

  local weapon = client:GetActiveWeapon()

  if !IsValid(weapon) or weapon:GetClass() != 'gmod_tool' or weapon:GetMode() != 'mapscene' then return end
  if IsValid(Flux.intro_panel) or !can('manage_map_scenes') then return end

  local points = self.points
  local count = #points

  if points != labeled_points or count != labeled_count then
    labeled_points = points
    labeled_count = count

    for k = 1, count do
      title_args.index = k
      labels[k] = t('ui.mapscene.point', title_args)
    end
  end

  cam.Start3D()
    render.SetMaterial(marker_material)

    for k = 1, count do
      local v = points[k]
      local pos = v.pos

      render.DrawSphere(pos, 5, 10, 10, marker_color)
      render.DrawLine(pos, pos + v.ang:Forward() * 20, marker_color)
    end
  cam.End3D()

  local font = Theme.get_font('text_small')

  for k = 1, count do
    local screen_pos = points[k].pos:ToScreen()

    draw.SimpleText(labels[k], font, screen_pos.x, screen_pos.y, marker_color)
  end
end

local view = {}

--- Replaces the view with the current mapscene point while the ShouldMapsceneRender hook
-- returns true. Depending on the config it cuts to the next point with a fade, glides
-- between the points or slowly rotates the camera, at the same speed at any frame rate.
-- @param _client [Player]
-- @param _origin [Vector]
-- @param _angles [Angle]
-- @param _fov [Number]
-- @return [Map view table with origin and angles, or nil if no mapscene is shown]
function MapScenes:CalcView(_client, _origin, _angles, _fov)
  --- Asks whether the mapscene camera should replace the local player's view.
  -- Called on the client on every view calculation. The Characters plugin returns true while
  -- the intro panel or the main menu is open.
  -- @return [Boolean Return true to show the mapscene; the view is left alone otherwise]
  if hook.Run('ShouldMapsceneRender') then
    local points = self.points
    local count = #points

    if count > 0 then
      local cur_time = CurTime()
      local animated = config_get('map_scenes_animated')

      self.scene = self.scene or 1

      if self.scene > count then
        self.scene = 1
      end

      if !animated and count > 1 then
        self.next_scene = self.next_scene or cur_time + config_get('map_scenes_speed')

        if self.next_scene <= cur_time then
          PLAYER:ScreenFade(SCREENFADE.IN, color_black, 2, 0)
          self.scene += 1
          self.next_scene = cur_time + config_get('map_scenes_speed')

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
          self.end_time = self.end_time or cur_time + config_get('map_scenes_speed')

          local fraction = math.min(1, math.TimeFraction(self.start_time, self.end_time, cur_time))

          self.pos = LerpVector(fraction, point.pos, next_point.pos)
          self.ang = LerpAngle(fraction, point.ang, next_point.ang)

          if self.pos:DistToSqr(next_point.pos) < 1 then
            self.scene += 1
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
          local rotate_speed = config_get('map_scenes_rotate_speed')

          if rotate_speed > 0 then
            self.angle_offset = self.angle_offset or Angle()
            self.angle_offset.y += rotate_speed * 60 * FrameTime()
            self.ang += self.angle_offset
          end
        end

        view.origin = self.pos
        view.angles = self.ang

        return view
      end
    end
  end
end
