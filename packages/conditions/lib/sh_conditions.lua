--- Registry of the condition types. A condition type, such as 'health' or 'steamid', is
-- registered with `Conditions:register_condition` and defines how its parameters are chosen
-- in the editor and how it is checked against a player. The registry is kept across code
-- refreshes, and registering an ID again replaces the type.

local stored = Conditions.stored or {}
Conditions.stored = stored

local process_operator = util.process_operator
local operator_to_symbol = util.operator_to_symbol

--- Builds the get_args function of a condition type that compares one parameter.
-- @param parameter [String key of the parameter in the node data and in the text phrase]
-- @return [Function get_args(panel, data)]
local function default_get_args(parameter)
  return |panel, _data| -> {
    operator = operator_to_symbol(panel.data.operator) or '',
    [parameter] = panel.data[parameter] or ''
  }
end

--- Builds the check function of a condition type that compares one parameter with a value of
-- the player. The check fails while the operator or the parameter is not set and when the
-- player has no such value.
-- @param parameter [String key of the parameter in the node data]
-- @param get_value [Function get_value(target, data) returns the value of the player]
-- @return [Function check(target, data)]
local function default_check(parameter, get_value)
  return function(target, data)
    local expected = data[parameter]

    if !data.operator or expected == nil then return false end

    local value = get_value(target, data)

    if value == nil then return false end

    return process_operator(data.operator, value, expected)
  end
end

--- Checks the set_operator field of a condition definition: nil, a function, or the name of
-- a set of operators that util has a `get_<name>_operators` function for.
-- @param set_operator [Any]
-- @return [Boolean]
local function is_operator_set(set_operator)
  if set_operator == nil or isfunction(set_operator) then return true end

  return isstring(set_operator) and isfunction(util['get_'..set_operator..'_operators'])
end

--- Registers a condition type that can be picked in the conditions editor
-- and evaluated with Conditions:check.
-- ```
-- Conditions:register_condition('health', {
--   name = 'condition.health.name', -- phrase displayed in the 'add condition' menu
--   text = 'condition.health.text', -- phrase of the node, 'Health {operator} {health}'
--   icon = 'icon16/heart.png',
--   -- Operator set to pick from: 'equal', 'relational' or 'logical'.
--   -- Can also be a function(id, data, panel, menu) that sets panel.data.operator.
--   set_operator = 'relational',
--   -- The key of the parameter in panel.data and in the 'text' phrase, and the value of the
--   -- player it is compared with. Together they stand for the get_args and check below.
--   parameter = 'health',
--   get_value = target -> target:Health(),
--   -- Clientside. Lets the user choose the parameters of the condition.
--   set_parameters = function(id, data, panel, menu, parent)
--     Derma_StringRequest(t(data.name), t'condition.health.message', '', function(text)
--       panel.data.health = tonumber(text)
--
--       panel.update()
--     end)
--   end
-- })
-- ```
-- A type that needs more than one parameter or a check of its own gives get_args and check
-- instead of parameter and get_value; given ones take precedence over the ones that parameter
-- stands for:
-- ```
-- -- Returns the arguments for the 'text' phrase.
-- get_args = function(panel, data)
--   return { operator = util.operator_to_symbol(panel.data.operator) or '', health = panel.data.health or '' }
-- end,
-- -- Serverside. Receives the parameters that were stored in panel.data. The condition passes
-- -- only when this returns true.
-- check = function(target, data)
--   if !data.operator or !data.health then return false end
--
--   return util.process_operator(data.operator, target:Health(), data.health)
-- end
-- ```
-- A definition without a check function, or whose set_operator names no set of operators, is
-- reported in the console; a condition without a check never passes.
-- @param id [String unique condition id]
-- @param data [Map condition definition: name, text, icon, set_operator, parameter, the
--   get_value(target, data), get_args(panel, data), check(target, data) and
--   set_parameters(id, data, panel, menu, parent) functions]
-- @see [Conditions:check]
function Conditions:register_condition(id, data)
  if !isstring(id) or !istable(data) then
    ErrorNoHalt("Conditions: not registering the '"..tostring(id).."' condition, it needs a string id and a table!\n")

    return
  end

  local parameter = data.parameter

  if isstring(parameter) then
    data.get_args = data.get_args or default_get_args(parameter)

    if isfunction(data.get_value) then
      data.check = data.check or default_check(parameter, data.get_value)
    end
  end

  if SERVER and !isfunction(data.check) then
    ErrorNoHalt("Conditions: the '"..id.."' condition has no check function and never passes!\n")
  end

  if !is_operator_set(data.set_operator) then
    ErrorNoHalt("Conditions: the '"..id.."' condition has an unknown set_operator '"..
      tostring(data.set_operator).."'!\n")
  end

  stored[id] = data
end

--- Returns all registered condition types.
-- @return [Map condition definitions keyed by condition id]
function Conditions:get_all()
  return stored
end
