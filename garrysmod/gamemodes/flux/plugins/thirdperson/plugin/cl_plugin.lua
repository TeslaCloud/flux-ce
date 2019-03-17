local start_time = ThirdPerson.start_time or nil
local offset = ThirdPerson.offset or Vector(0, 0, 0)
ThirdPerson.start_time = start_time
ThirdPerson.offset = offset

local duration = 0.15

local flipped_start = ThirdPerson.flipped_start or false
ThirdPerson.flipped_start = flipped_start

ThirdPerson.was_third_person = ThirdPerson.was_third_person or false

-- This is very basic and WIP, but it works.
function ThirdPerson:CalcView(player, pos, angles, fov)
  local is_third_person = player:get_nv('third_person')

  -- This also fixes weird view glitch on autorefresh.
  if !is_third_person and !self.was_third_person then return end

  local view = {}
  local cur_time = CurTime()

  view.origin = pos
  view.angles = angles
  view.fov = fov

  if is_third_person then
    if !start_time or flipped_start then
      start_time = cur_time
      flipped_start = false
    end

    local forward = angles:Forward() * 75
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

    local forward = angles:Forward() * 75
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

  return view
end

Flux.Binds:add_bind('ToggleThirdPerson', 'fl_third_person', KEY_X)
