function ActiveRecord.dump_schema()
  local result = [[--
-- This is an ActiveRecord schema file.
-- Dumped at ]]..os.date('%Y-%m-%d %H:%M:%S', os.time())..[[ 
--
local Structure = ActiveRecord.define_structure(]]..os.date('%Y%m%d%H%M%S', os.time())..[[)
  function Structure:create_tables()
]]

  local level = 2
  local ind = '  '

  for table_name, structure in pairs(ActiveRecord.schema) do
    result = result + '\n' + string.rep(ind, level) + 'create_table(\'' + table_name + '\', function(t)\n'
    level = level + 1
    for column_name, abstract_type in pairs(structure) do
      result = result + string.rep(ind, level) + 't:' + abstract_type + ' \'' + column_name + '\'\n'
    end
    level = level - 1
    result = result + string.rep(ind, level) + 'end)\n'
  end

  result = result + [[
  end
return Structure
]]

  return result
end
