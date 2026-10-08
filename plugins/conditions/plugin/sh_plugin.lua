--- Conditions are rules about a player that are edited in game and checked on the server.
-- A condition type, such as 'health' or 'steamid', is registered with
-- `Conditions:register_condition` and defines how its parameters are chosen in the editor and
-- how it is checked against a player. The `fl_conditions` panel edits a tree of conditions,
-- and `Conditions:check` tests a player against such a tree: the conditions on one level are
-- alternatives, and a condition that has child conditions also needs one of those to pass. The
-- Doors plugin, for example, uses a tree to decide who may lock a door.
--
-- Plugins register their condition types from the `RegisterConditions` hook.

PLUGIN:set_global('Conditions')

local stored = Conditions.stored or {}
Conditions.stored = stored

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
--   -- Returns the arguments for the 'text' phrase.
--   get_args = function(panel, data)
--     local operator = util.operator_to_symbol(panel.data.operator) or ''
--     local parameter = panel.data.health or ''
--
--     return { operator = operator, health = parameter }
--   end,
--   -- Serverside. Receives the parameters that were stored in panel.data.
--   check = function(target, data)
--     if !data.operator or !data.health then return false end
--
--     return util.process_operator(data.operator, target:Health(), data.health)
--   end,
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
-- @param id [String unique condition id]
-- @param data [Map condition definition: name, text, icon, set_operator and the
--   get_args(panel, data), check(target, data) and
--   set_parameters(id, data, panel, menu, parent) functions]
-- @see [Conditions:check]
function Conditions:register_condition(id, data)
  stored[id] = data
end

--- Returns all registered condition types.
-- @return [Map condition definitions keyed by condition id]
function Conditions:get_all()
  return stored
end

require_relative 'sh_config'
require_relative 'sv_plugin'

--- Runs the RegisterConditions hook so that plugins can register their conditions.
function Conditions:OnPluginsLoaded()
  --- Lets plugins register their condition types with `Conditions:register_condition`. Called
  -- on the server and the client once all plugins have been loaded.
  hook.Run('RegisterConditions')
end
