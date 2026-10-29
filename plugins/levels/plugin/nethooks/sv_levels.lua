--- Server-side receivers of the Levels plugin: the requests of clients to spend a skill
-- point or an attribute point of the character of their player.

local IsValid = IsValid
local isstring = isstring

Cable.receive('fl_levels_spend_skill', function(actor, skill_id)
  if !IsValid(actor) or !isstring(skill_id) then return end

  local success, phrase = actor:spend_skill_point(skill_id)

  if !success then
    actor:notify(phrase)
  end
end)

Cable.receive('fl_levels_spend_attribute', function(actor, stat_id)
  if !IsValid(actor) or !isstring(stat_id) then return end

  local success, phrase = actor:spend_attribute_point(stat_id)

  if !success then
    actor:notify(phrase)
  end
end)
