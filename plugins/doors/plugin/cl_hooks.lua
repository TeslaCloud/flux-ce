--- Client-side hooks of the Doors plugin: draws the titles of doors in the world and keeps
-- the status texts of the doors up to date.

local IsValid = IsValid
local find_in_sphere = ents.FindInSphere
local trace_line = util.TraceLine
local start_3d2d = cam.Start3D2D
local end_3d2d = cam.End3D2D

local title_distance = 256
local inverse_title_distance = 1 / title_distance
local title_scale = 0.05
local offset_side = Angle(0, 90, 90)
local offset_front = Angle(0, 0, 90)
local offset_flat = Angle(90, 90, 0)
local offset_back = Angle(0, 180, 0)
local trace_data = {
  collisiongroup = COLLISION_GROUP_WORLD,
  ignoreworld = true
}

--- Makes a door work its status text out again when one of its ownership variables
-- ('fl_door_ownable', 'fl_door_price', 'fl_door_owner' or 'fl_door_text') has changed.
-- @param entity [Entity the entity whose variable has changed]
-- @param key [String variable name]
function Doors:NetVarChanged(entity, key)
  if key:start_with('fl_door_') then
    self:invalidate_status_text(entity)
  end
end

--- Makes every door work its status text out again when the language changes.
function Doors:LanguageChanged()
  self:invalidate_status_texts()
end

--- Makes every door work its status text out again when the door_price config changes.
-- @param key [String config key]
function Doors:OnConfigReceived(key)
  if key == 'door_price' then
    self:invalidate_status_texts()
  end
end

--- Draws the titles of the doors within 256 units of the camera on both sides
-- of the door, using the title type that is set on each door. A door that is ownable or
-- owned and has never been given a title type is drawn with `Doors.default_title_type`, so
-- that its status shows; choosing the disabled title type for it turns that off.
-- @param depth [Boolean whether the depth pass is being drawn]
-- @param skybox [Boolean whether the skybox is being drawn]
function PLUGIN:PostDrawTranslucentRenderables(depth, skybox)
  if depth or skybox then return end

  local eye_pos = EyePos()
  local doors = Doors
  local title_types = doors.title_types
  local found = find_in_sphere(eye_pos, title_distance)

  for i = 1, #found do
    local v = found[i]

    if IsValid(v) and v:is_door() then
      local title = v:get_nv('fl_title_type')

      if title == nil and (doors:is_ownable(v) or doors:is_owned(v)) then
        title = doors.default_title_type
      end

      local title_data = title_types[title]

      if !title or title == '' or !title_data or !title_data.draw then
        continue
      end

      local ang, pos = v:GetAngles(), v:LocalToWorld(v:OBBCenter())
      local mins, maxs = v:OBBMins(), v:OBBMaxs()
      local size = maxs - mins
      local alpha = 255 * (1 - eye_pos:Distance(pos) * inverse_title_distance)
      local ang_offset, pos_offset
      local w, h

      if size.x < size.y and size.x < size.z then
        ang_offset = offset_side
        pos_offset = v:GetForward() * size.x * 0.5

        w = size.y
        h = size.z
      elseif size.y < size.z then
        ang_offset = offset_front
        pos_offset = v:GetRight() * size.y * 0.5

        w = size.x
        h = size.z
      elseif size.z < size.y then
        ang_offset = offset_flat
        pos_offset = v:GetUp() * size.z * 0.5

        w = size.x
        h = size.y
      end

      ang:Add(ang_offset)

      trace_data.start = pos + pos_offset
      trace_data.endpos = pos

      local trace = trace_line(trace_data)
      local draw_w, draw_h = w / title_scale, h / title_scale

      if trace.HitNormal:Dot((eye_pos - pos):GetNormalized()) > 0 then
        start_3d2d(trace.HitPos + pos_offset * 0.05, ang, title_scale)
          title_data.draw(v, draw_w, draw_h, alpha)
        end_3d2d()
      else
        start_3d2d(pos + (pos - trace.HitPos) * 1.05, ang + offset_back, title_scale)
          if title_data.draw_back then
            title_data.draw_back(v, draw_w, draw_h, alpha)
          else
            title_data.draw(v, draw_w, draw_h, alpha)
          end
        end_3d2d()
      end
    end
  end
end
