--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

local startTime = flThirdPerson.startTime or nil
flThirdPerson.startTime = startTime

local offset = flThirdPerson.offset or Vector(0, 0, 0)
flThirdPerson.offset = offset

local duration = 0.15

local flippedStart = flThirdPerson.flippedStart or false
flThirdPerson.flippedStart = flippedStart

flThirdPerson.wasThirdPerson = flThirdPerson.wasThirdPerson or false

-- This is very basic and WIP, but it works.
function flThirdPerson:CalcView(player, pos, angles, fov)
  local isThirdPerson = player:GetNetVar("flThirdPerson")

  -- This also fixes weird view glitch on autorefresh.
  if (!isThirdPerson and !self.wasThirdPerson) then return end

  local view = {}
  local curTime = CurTime()

  view.origin = pos
  view.angles = angles
  view.fov = fov

  if (isThirdPerson) then
    if (!startTime or flippedStart) then
      startTime = curTime
      flippedStart = false
    end

    local forward = angles:Forward() * 75
    local fraction = (curTime - startTime) / duration

    if (fraction <= 1) then
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
    if (!flippedStart) then
      startTime = curTime
      flippedStart = true
    end

    local forward = angles:Forward() * 75
    local fraction = (curTime - startTime) / duration

    if (fraction <= 1) then
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
