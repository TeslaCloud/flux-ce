--- Client-side receivers of the Stats plugin: the results of the rolls of the character
-- sheet, and the attributes and skills of another player's character that the server sends
-- to a member of staff.

Cable.receive('fl_stats_roll_result', function(id, result)
  if !isstring(id) then return end

  if !istable(result) or !isnumber(result.total) then
    Stats.rolls[id] = nil

    return
  end

  local now = RealTime()
  local roll = Stats.rolls[id] or { started = now }
  local definition = Attributes.find(id) or Skills.find(id)

  roll.pending = false
  roll.result = result
  roll.landed = math.max(now, roll.started + Stats.roll_tumble_time)
  roll.text = t('ui.character_sheet.roll_result', {
    name = definition and t(definition.name) or id,
    roll = Stats:format_roll(result)
  })

  Stats.rolls[id] = roll

  --- Called on the client when the server has answered a roll that the local player made
  -- from the character sheet, after the result has been stored for `Stats:get_roll`.
  -- @param id [String ID of the stat or the skill]
  -- @param result [Map formula, total, natural, critical and rolls of the `Dice` result]
  hook.Run('OnStatRollResult', id, result)
end)

Cable.receive('fl_attributes_view', function(target, attributes, skills)
  if !istable(attributes) then return end

  Attributes.open_viewer(target, attributes, skills)
end)
