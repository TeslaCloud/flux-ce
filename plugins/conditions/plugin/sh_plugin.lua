--- Conditions are rules about a player that are edited in game and checked on the server.
-- A condition type, such as 'health' or 'steamid', is registered with
-- `Conditions:register_condition` and defines how its parameters are chosen in the editor and
-- how it is checked against a player. The `fl_conditions` panel edits a tree of conditions,
-- and `Conditions:check` tests a player against such a tree: the conditions on one level are
-- alternatives, and a condition that has child conditions also needs one of those to pass. The
-- Doors plugin, for example, uses a tree to decide who may lock a door.
--
-- Plugins register their condition types from the `RegisterConditions` hook.

require_relative 'sv_plugin'

--- Runs the RegisterConditions hook so that plugins can register their conditions.
function Conditions:OnPluginsLoaded()
  --- Lets plugins register their condition types with `Conditions:register_condition`. Called
  -- on the server and the client once all plugins have been loaded.
  hook.Run('RegisterConditions')
end
