local function CheckConditions(player, conditions)
  for k, v in pairs(conditions) do
    local condition_table = Conditions:get_all()[v.id]

    if condition_table.check and condition_table.check(player, v.data) == false or
    #v.childs != 0 and CheckConditions(player, v.childs) == false then
      continue
    end

    return true
  end

  return false
end

function Conditions:check(player, conditions)
  return CheckConditions(player, conditions)
end
