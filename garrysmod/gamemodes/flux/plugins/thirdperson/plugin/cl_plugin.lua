local start_time = flThirdPerson.start_time or nil
flThirdPerson.start_time = start_time

local offset = flThirdPerson.offset or Vector(0, 0, 0)
flThirdPerson.offset = offset

local duration = 0.15

local flippedStart = flThirdPerson.flippedStart or false
flThirdPerson.flippedStart = flippedStart

flThirdPerson.wasThirdPerson = flThirdPerson.wasThirdPerson or false

-- This is very basic and WIP, but it works.
function flThirdPerson:CalcView(player, pos, angles, fov)
  local isThirdPerson = player:get_nv("flThirdPerson")

  -- This also fixes weird view glitch on autorefresh.
  if !isThirdPerson and !self.wasThirdPerson then return end

  local view = {}
  local curTime = CurTime()

  view.origin = pos
  view.angles = angles
  view.fov = fov

  if isThirdPerson then
    if !start_time or flippedStart then
      start_time = curTime
      flippedStart = false
    end

    local forward = angles:Forward() * 75
    local fraction = (curTime - start_time) / duration

    if fraction <= 1 then
      offset.x = Lerp(fraction, 0, forward.x)
      offset.y = Lerp(fraction, 0, forward.y)
      offset.z = Lerp(fraction, 0, forward.z)
    else
      offset = forward
    end

    view.origin = pos - offset
    view.drawviewer = true

    self.wasThirdPerson = true
  else
    if !flippedStart then
      start_time = curTime
      flippedStart = true
    end

    local forward = angles:Forward() * 75
    local fraction = (curTime - start_time) / duration

    if fraction <= 1 then
      offset.x = Lerp(fraction, forward.x, 0)
      offset.y = Lerp(fraction, forward.y, 0)
      offset.z = Lerp(fraction, forward.z, 0)
      view.drawviewer = true
    else
      offset = Vector(0, 0, 0)
      self.wasThirdPerson = false
    end

    view.origin = pos - offset
  end

  return view
end

fl.binds:AddBind("ToggleThirdPerson", "flThirdPerson", KEY_X)
