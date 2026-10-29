--- Entry point of the Conditions package, run on both realms. Conditions are rules about a
-- player that are edited in game and checked on the server.
--
-- A condition type, such as 'health' or 'steamid', is registered with
-- `Conditions:register_condition` and defines how its parameters are chosen in the editor and
-- how it is checked against a player. The `fl_conditions` panel edits a tree of conditions,
-- and `Conditions:check` tests a player against such a tree: the conditions on one level are
-- alternatives, and a condition that has child conditions also needs one of those to pass. The
-- Doors plugin, for example, uses a tree to decide who may lock a door.
--
-- The package registers the 'steamid', 'model', 'health', 'armor' and 'active_weapon' types
-- itself. Plugins register theirs at file level or from the `RegisterConditions` hook.
--
-- The package loads the registry, its condition types and the check, then the editor and the
-- hooks. On the server it also registers the package's languages with `Pipeline`. During a
-- partial code reload (`LITE_REFRESH`) nothing is loaded again.
-- @module [Conditions]

if !LITE_REFRESH then
  require_relative 'lib/sh_conditions'
  require_relative 'lib/sh_default_conditions'
  require_relative 'lib/sv_conditions'

  if SERVER then
    Pipeline.include_folder('language', PACKAGE.__path__..'languages')
  end

  require_relative_folder('views', true)
  require_relative_folder('hooks', true)
end
