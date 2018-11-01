local start_time = ThirdPerson.start_time or nil
ThirdPerson.start_time = start_time

local offset = ThirdPerson.offset or Vector(0, 0, 0)
ThirdPerson.offset = offset

local duration = 0.15

local flippedStart = ThirdPerson.flippedStart or false
ThirdPerson.flippedStart = flippedStart

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
    if !start_time or flippedStart then
      start_time = cur_time
      flippedStart = false
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
    if !flippedStart then
      start_time = cur_time
      flippedStart = true
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

fl.binds:add_bind('ToggleThirdPerson', 'flThirdPerson', KEY_X)
