--- Server side of the Conditions package: checks a player against a tree of conditions.

local function check_conditions(target, conditions)
  local stored = Conditions:get_all()

  for _, condition in pairs(conditions) do
    local condition_table = istable(condition) and stored[condition.id]

    if !condition_table then continue end

    local data = istable(condition.data) and condition.data or {}
    local childs = istable(condition.childs) and condition.childs or {}

    if condition_table.check and condition_table.check(target, data) == false or
    #childs != 0 and check_conditions(target, childs) == false then
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
-- registered, such as one saved by a plugin that is not loaded.
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
--   returned by the get_conditions method of the fl_conditions panel]
-- @return [Boolean]
function Conditions:check(target, conditions)
  return check_conditions(target, conditions)
end
