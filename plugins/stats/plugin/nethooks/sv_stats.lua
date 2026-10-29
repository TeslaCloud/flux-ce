--- Server-side receiver of the Stats plugin: the rolls of attributes and skills that a player
-- asks for from the character sheet, answered with the 'fl_stats_roll_result' message.

local IsValid = IsValid

--- Picks the fields of a roll result that the character sheet needs to show it, leaving out
-- anything a handler of the AdjustAttributeRoll hook may have hung on the result.
-- @param result [Map result of `Dice.roll`]
-- @return [Map formula, total, natural, critical and rolls]
local function roll_summary(result)
  local rolls = {}

  for i, roll in ipairs(istable(result.rolls) and result.rolls or {}) do
    rolls[i] = {
      sides = roll.sides,
      results = roll.results,
      kept = roll.kept,
      dropped = roll.dropped,
      total = roll.total
    }
  end

  return {
    formula = result.formula,
    total = result.total,
    natural = result.natural,
    critical = result.critical,
    rolls = rolls
  }
end

Cable.receive('fl_stats_roll', function(actor, id)
  if !IsValid(actor) or !isstring(id) or !actor:is_character_loaded() then return end

  local cur_time = CurTime()

  if (actor.next_stats_roll or 0) > cur_time then
    Cable.send(actor, 'fl_stats_roll_result', id, nil)

    return
  end

  actor.next_stats_roll = cur_time + Stats.roll_interval

  local result = Stats:roll_and_announce(actor, id)

  Cable.send(actor, 'fl_stats_roll_result', id, result and roll_summary(result) or nil)
end)
