--- Server-side receivers of the Gamemastery plugin, behind the gamemaster panel: the pool
-- list, possessing and releasing pool characters, placing them in the world and deleting them.
-- Every request needs a gamemaster and is taken once a second at most.

local isnumber = isnumber
local isstring = isstring
local isvector = isvector
local math_abs = math.abs
local math_huge = math.huge

--- Checks whether a number is neither NaN nor infinite.
-- @param number [Number]
-- @return [Boolean]
local function is_finite(number)
  return isnumber(number) and number == number and math_abs(number) != math_huge
end

local function answer(actor, success, phrase, arguments, reason, reason_arguments)
  if success then
    actor:notify(phrase, arguments)
  elseif isstring(reason) then
    actor:notify(reason, reason_arguments)
  end
end

local function accept_action(actor)
  if !Gamemastery.is_gamemaster(actor) then return false end

  if Gamemastery.is_throttled(actor, 'action') then
    actor:notify('error.gamemastery.wait')

    return false
  end

  return true
end

Cable.receive('fl_gm_pool_request', function(actor)
  if !Gamemastery.is_gamemaster(actor) or Gamemastery.is_throttled(actor, 'pool') then return end

  Gamemastery.send_pool(actor)
end)

Cable.receive('fl_gm_possess', function(actor, id)
  if !isnumber(id) or !accept_action(actor) then return end

  local character = Gamemastery.find_character(id)
  local success, reason, arguments = Gamemastery.possess(actor, character)

  local name = character and character.name

  answer(actor, success, 'notification.gamemastery.possessed', { name = name }, reason, arguments)
end)

Cable.receive('fl_gm_release', function(actor)
  if !accept_action(actor) then return end

  local success, result = Gamemastery.release(actor)

  if success then
    actor:notify('notification.gamemastery.released', { name = result.name })
  else
    actor:notify(result)
  end
end)

Cable.receive('fl_gm_spawn', function(actor, id, direction)
  if !isnumber(id) or !isvector(direction) then return end
  if !is_finite(direction.x) or !is_finite(direction.y) or !is_finite(direction.z) then return end
  if direction:LengthSqr() == 0 or !accept_action(actor) then return end

  local character = Gamemastery.find_character(id)
  local name = character and character.name
  local success, reason, arguments = Gamemastery.spawn_in_world(actor, character, direction:GetNormalized())

  answer(actor, success, 'notification.gamemastery.placed', { name = name }, reason, arguments)
end)

Cable.receive('fl_gm_delete', function(actor, id)
  if !isnumber(id) or !accept_action(actor) then return end

  local success, reason, arguments = Gamemastery.delete(actor, Gamemastery.find_character(id))

  if !success then
    actor:notify(reason, arguments)
  end
end)
