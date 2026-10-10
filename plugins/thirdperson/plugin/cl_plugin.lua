--- Client side of the Third Person plugin: calculates the third person view and adds the key
-- bind that toggles it.

local start_time = ThirdPerson.start_time or nil
local offset = ThirdPerson.offset or Vector(0, 0, 0)
ThirdPerson.start_time = start_time
ThirdPerson.offset = offset

local duration = 0.15
local view = {}
local trace_data = {}

local flipped_start = ThirdPerson.flipped_start or false
ThirdPerson.flipped_start = flipped_start

ThirdPerson.was_third_person = ThirdPerson.was_third_person or false

-- This is very basic and WIP, but it works.

--- Pulls the camera back behind the player while third person is on, easing in and out
-- over 0.15 seconds. The camera stops in front of the walls that are in its way, and the
-- view becomes first person when it gets too close to the player.
-- @param client [Player]
-- @param pos [Vector]
-- @param angles [Angle]
-- @param fov [Number]
-- @return [Map view table, or nil while third person is off and not easing out]
function ThirdPerson:CalcView(client, pos, angles, fov)
  local is_third_person = client:get_nv('fl_third_person')

  -- This also fixes a weird view glitch on autorefresh.
  if !is_third_person and !self.was_third_person then return end

  local cur_time = CurTime()
  local forward_dir = angles:Forward()

  view.origin = pos
  view.angles = angles
  view.fov = fov
  view.drawviewer = nil

  if is_third_person then
    if !start_time or flipped_start then
      start_time = cur_time
      flipped_start = false
    end

    local forward = forward_dir * 75
    local fraction = (cur_time - start_time) / duration

    if fraction <= 1 then
      offset.x = Lerp(fraction, 0, forward.x)
      offset.y = Lerp(fraction, 0, forward.y)
      offset.z = Lerp(fraction, 0, forward.z)
    else
      offset = forward
    end

    view.origin = pos - offset
    view.drawviewer = true

    self.was_third_person = true
  else
    if !flipped_start then
      start_time = cur_time
      flipped_start = true
    end

    local forward = forward_dir * 75
    local fraction = (cur_time - start_time) / duration

    if fraction <= 1 then
      offset.x = Lerp(fraction, forward.x, 0)
      offset.y = Lerp(fraction, forward.y, 0)
      offset.z = Lerp(fraction, forward.z, 0)
      view.drawviewer = true
    else
      offset = Vector(0, 0, 0)
      self.was_third_person = false
    end

    view.origin = pos - offset
  end

  trace_data.start = pos
  trace_data.endpos = view.origin
  trace_data.filter = client

  local tr = util.TraceLine(trace_data)

  if tr.HitWorld then
    view.origin = tr.HitPos + forward_dir * 15
  end

  if view.origin:DistToSqr(pos) < 100 then
    view.origin = pos
    view.drawviewer = false
  end

  return view
end

Flux.Binds:add_bind('ToggleThirdPerson', 'fl_third_person', KEY_P)
