--- The `roll` command: rolls dice and shows the result to the players nearby. Without an
-- argument it rolls a d20, a number rolls a die with that many sides, the name of a stat
-- or a skill of the Stats plugin rolls that stat or skill, and anything else is read as a
-- formula of the `Dice` library, such as `2d6 + 3` or `4d6kh3`. A formula can use the
-- IDs of stats and skills, which stand for the modifiers of the player, and `level`, the
-- level of their character. While the 'roll_versus' config is enabled, rolling while
-- looking at a nearby player rolls the same thing for both of them in one line. Plugins can
-- adjust any roll through the `PlayerAdjustRoll` hook.

local config_get = Config.get

CMD.name = 'Roll'
CMD.description = 'command.roll.description'
CMD.syntax = 'command.roll.syntax'
CMD.category = 'permission.categories.roleplay'
CMD.arguments = 0
CMD.no_console = true

local max_range = 1000000
local default_formula = '1d20'

--- Returns the level of a player's character for the `level` variable of a formula.
-- @param target [Player]
-- @return [Number the level from the Levels plugin, 1 without it]
local function get_character_level(target)
  if Stats and isfunction(Stats.get_character_level) then
    return Stats:get_character_level(target)
  end

  if Levels and isfunction(target.get_level) then
    return tonumber(target:get_level()) or 1
  end

  return 1
end

--- Builds the function that gives the variables of a formula their values for a player:
-- `level` is the level of their character, and the name of a stat or a skill is the
-- modifier the player has in it.
-- @param target [Player player the formula is rolled for]
-- @return [Function taking the name of a variable and returning its Number value, or nil
--   for a name that is neither]
local function get_variables(target)
  return function(name)
    if !isstring(name) then return end

    name = name:lower()

    if name == 'level' then
      return get_character_level(target)
    end

    if Stats and isfunction(Stats.find_rollable) then
      local rollable = Stats:find_rollable(name)

      if !rollable then return end

      if rollable.kind == 'skill' then
        return target:get_skill_modifier(rollable.id)
      end

      return target:get_attribute_modifier(rollable.id)
    end

    if Attributes and Attributes.find(name) then
      local level = target:get_attribute(name)

      return level
    end
  end
end

--- Lets plugins adjust a roll and makes sure that its total is still a number.
-- @param roller [Player player the roll is for]
-- @param result [Map result of `Dice.roll`]
-- @param formula [String formula that was rolled, or the ID of the stat or skill]
-- @param opponent=nil [Player player the roll is made against, if it is a versus roll]
-- @return [Map the result]
local function adjust_roll(roller, result, formula, opponent)
  local total = result.total
  local roll_data = {
    result = result,
    formula = formula,
    opponent = opponent
  }

  --- Lets plugins adjust a roll made with the `roll` command, for example to add a
  -- situational bonus. Called on the server once for every roll: once for a plain roll, and
  -- for a versus roll once for the player who ran the command and once for their opponent.
  -- Every handler can change the roll, so return nothing.
  -- @param roller [Player the player the roll is for]
  -- @param roll_data [Map the roll: result (Map the result of `Dice.roll`; change its total
  --   in place, a total that is not a number is put back), formula (String the formula
  --   that was rolled, or the ID of the stat or the skill) and opponent (Player the other
  --   player of a versus roll, nil for a plain roll)]
  hook.Run('PlayerAdjustRoll', roller, roll_data)

  local adjusted = tonumber(result.total)

  if !adjusted or adjusted != adjusted then
    result.total = total
  end

  return result
end

--- Rolls what the argument of the command asks for, for one player.
-- @param target [Player player to roll for]
-- @param formula [String Dice formula, used when there is no rollable]
-- @param rollable=nil [Map id and kind of a stat or a skill to roll instead]
-- @return [Map result of the roll, or nil and String the error]
local function roll_for(target, formula, rollable)
  if rollable then
    if rollable.kind == 'skill' then
      return target:roll_skill(rollable.id)
    end

    return target:roll_attribute(rollable.id)
  end

  return Dice.roll(formula, get_variables(target))
end

--- Finds the player a roll is made against: the living player the caller is looking at, or
-- the one whose ragdoll they are looking at, within the talk radius.
-- @param actor [Player player running the command]
-- @return [Player the opponent; nothing if versus rolls are disabled or the caller is not
--   looking at a nearby player]
local function find_opponent(actor)
  if !config_get('roll_versus') then return end

  local entity = actor:GetEyeTraceNoCursor().Entity

  if !IsValid(entity) then return end

  local target = entity

  if !entity:IsPlayer() and isfunction(entity.get_ragdoll_owner) then
    target = entity:get_ragdoll_owner()
  end

  if !IsValid(target) or !target:IsPlayer() or target == actor or !target:Alive() then return end

  local radius = config_get('talk_radius')

  if entity:GetPos():DistToSqr(actor:GetPos()) > radius * radius then return end

  return target
end

--- Works out what the argument of the command asks to roll: a d20 without one, a die with
-- that many sides for a number (from 1 to 1000000), a stat or a skill for its name, and a
-- formula for anything else.
-- @param text [String the argument]
-- @return [String formula, Map id and kind of the stat or skill to roll, or nil]
local function resolve(text)
  if text == '' then
    return default_formula
  end

  local range = tonumber(text)

  if range and range == range then
    return '1d'..math.floor(math.Clamp(range, 1, max_range))
  end

  if Stats and isfunction(Stats.find_rollable) then
    local rollable = Stats:find_rollable(text)

    if rollable then
      return rollable.id, rollable
    end
  end

  return text
end

--- Rolls dice and shows the result to nearby players. Looking at a nearby player makes it
-- a versus roll, which rolls the same thing for that player and is shown to the players
-- near either of them. A formula that cannot be rolled is reported to the caller.
-- @param actor [Player player running the command]
function CMD:on_run(actor, ...)
  local formula, rollable = resolve(table.concat({ ... }, ' '):strip())

  if !rollable then
    local ast, err = Dice.parse(formula)

    if !ast then
      actor:notify('error.roll.invalid', { message = tostring(err) })

      return
    end
  end

  local result, err = roll_for(actor, formula, rollable)

  if !result then
    actor:notify('error.roll.invalid', { message = tostring(err) })

    return
  end

  local label = rollable and t(Attributes.find(rollable.id).name) or nil
  local opponent = find_opponent(actor)
  local opponent_result

  adjust_roll(actor, result, formula, opponent)

  if opponent then
    opponent_result = roll_for(opponent, formula, rollable)

    if opponent_result then
      adjust_roll(opponent, opponent_result, formula, actor)
    else
      opponent = nil
    end
  end

  RPCommands:announce_roll(actor, result, opponent, opponent_result, label)
end
