local function CheckConditions(target, conditions)
  for k, v in pairs(conditions) do
    local condition_table = Conditions:get_all()[v.id]

    if condition_table.check and condition_table.check(target, v.data) == false or
    #v.childs != 0 and CheckConditions(target, v.childs) == false then
      continue
    end

    return true
  end

  return false
end

--- Checks whether the player satisfies a condition tree. Serverside only.
-- A list of nodes passes if at least one of its nodes does (OR). A node passes if its
-- own check passes and its list of child nodes, unless empty, passes as well (AND).
-- An empty top-level list never passes.
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
  return CheckConditions(target, conditions)
end
