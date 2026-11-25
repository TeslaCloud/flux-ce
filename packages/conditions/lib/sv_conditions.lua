--- Server side of the Conditions package: checks a player against a tree of conditions.

local operator_to_symbol = util.operator_to_symbol
local reported = {}

local function report_once(place, message)
  if reported[place] then return end

  reported[place] = true

  ErrorNoHalt(message)
end

--- Checks whether a node of a condition type may use an operator: one of the set its
-- `set_operator` names, or any known operator when the type picks its operator with a function
-- or has none. A type whose `set_operator` names no set allows none.
-- @param condition_table [Map the registered condition type]
-- @param operator [Any the operator of the node]
-- @return [Boolean]
local function is_operator_allowed(condition_table, operator)
  local set_operator = condition_table.set_operator

  if !isstring(set_operator) then
    return operator_to_symbol(operator) != nil
  end

  local get_operators = util['get_'..set_operator..'_operators']

  return isfunction(get_operators) and get_operators()[operator] != nil
end

--- Runs the check of one condition node. It passes only when the type has a check function,
-- the operator of the node, if it has one, is allowed for the type, and the check returns true
-- without an error. An operator that is not allowed and a failing check are reported once per
-- condition type.
-- @param id [String condition id]
-- @param condition_table [Map the registered condition type]
-- @param target [Player]
-- @param data [Map the parameters of the node]
-- @return [Boolean]
local function passes(id, condition_table, target, data)
  local check = condition_table.check

  if !isfunction(check) then return false end

  local operator = data.operator

  if operator != nil and !is_operator_allowed(condition_table, operator) then
    report_once('operator:'..id, "Conditions: a '"..id.."' condition has the operator '"..tostring(operator)..
      "', which its type does not allow, and does not pass!\n")

    return false
  end

  local success, result = pcall(check, target, data)

  if !success then
    report_once('error:'..id, "Conditions: the check of a '"..id.."' condition has failed, so it does not pass: "..
      tostring(result)..'\n')

    return false
  end

  return result == true
end

local function check_conditions(target, conditions)
  local stored = Conditions:get_all()

  for _, condition in pairs(conditions) do
    local condition_table = istable(condition) and stored[condition.id]

    if !condition_table then continue end

    local data = istable(condition.data) and condition.data or {}
    local childs = istable(condition.childs) and condition.childs or {}

    if !passes(condition.id, condition_table, target, data) or
    #childs != 0 and !check_conditions(target, childs) then
      continue
    end

    return true
  end

  return false
end

--- Checks whether the player satisfies a condition tree. Serverside only.
-- A list of nodes passes if at least one of its nodes does (OR). A node passes if its
-- own check passes and its list of child nodes, unless empty, passes as well (AND).
-- An empty top-level list never passes, and neither does a node whose condition type is not
-- registered, such as one saved by a plugin that is not loaded, a node with an operator that
-- its type does not allow, or a node whose check raises an error or returns anything but true.
-- ```
-- -- A specific player, or anyone with more than 50 health who holds a crowbar.
-- local allowed = Conditions:check(target, {
--   { id = 'steamid', data = { operator = 'equal', steamid = 'STEAM_0:1:12345' }, childs = {} },
--   { id = 'health', data = { operator = 'greater', health = 50 }, childs = {
--     { id = 'active_weapon', data = { operator = 'equal', weapon = 'weapon_crowbar' },
--       childs = {} }
--   } }
-- })
-- ```
-- @param target [Player]
-- @param conditions [List condition nodes, each a Map with id, data and childs, as
--   returned by the get_conditions method of the fl_conditions panel; anything else never
--   passes]
-- @return [Boolean]
function Conditions:check(target, conditions)
  if !istable(conditions) then return false end

  return check_conditions(target, conditions)
end
