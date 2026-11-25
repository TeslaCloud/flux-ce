--- Server-side receivers of the Levels plugin: the requests of clients to spend a skill
-- point or an attribute point of the character of their player. A player can send one of
-- them every `spend_interval` seconds; the others are dropped.

local IsValid = IsValid
local CurTime = CurTime
local isstring = isstring

local spend_interval = 0.2

--- Checks whether a player may send a spend request now, and notes the time of the request.
-- @param actor [Player]
-- @return [Boolean]
local function can_request(actor)
  local cur_time = CurTime()

  if (actor.fl_next_spend or 0) > cur_time then return false end

  actor.fl_next_spend = cur_time + spend_interval

  return true
end

Cable.receive('fl_levels_spend_skill', function(actor, skill_id)
  if !IsValid(actor) or !isstring(skill_id) or !can_request(actor) then return end

  local success, phrase = actor:spend_skill_point(skill_id)

  if !success then
    actor:notify(phrase)
  end
end)

Cable.receive('fl_levels_spend_attribute', function(actor, stat_id)
  if !IsValid(actor) or !isstring(stat_id) or !can_request(actor) then return end

  local success, phrase = actor:spend_attribute_point(stat_id)

  if !success then
    actor:notify(phrase)
  end
end)
