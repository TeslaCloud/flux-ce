local function table_to_inline(t)
  local ret = ''
  for k, v in pairs(t) do
    if ret != '' then
      ret = ret + ', '
    end

    if tonumber(k) then
      if !istable(v) then
        ret = ret + '"' + tostring(v) + '"'
      else
        ret = ret + '{ ' + table_to_inline(v) + ' }'
      end
    else
      ret = ret + tostring(k) + ' = '
      if !istable(v) then
        ret = ret + '"' + tostring(v) + '"'
      else
        ret = ret + '{ ' + table_to_inline(v) + ' }'
      end
    end
  end
  return ret
end

local function quote(what)
  return '"' + tostring(what) + '"'
end

function ActiveRecord.dump_schema(version)
  local result = [[--
-- This is an ActiveRecord schema file.
-- Dumped at ]]..to_datetime(os.time())..[[ 
--
local Structure = ActiveRecord.Schema:define(]]..version..[[)
  function Structure:create_tables()

]]

  local level = 2
  local ind = '  '

  for table_name, structure in pairs(ActiveRecord.schema or {}) do
    result = result + string.rep(ind, level) + 'create_table(\'' + table_name + '\', function(t)\n'
    level = level + 1
    for column_name, abstract_type in SortedPairsByValue(structure) do
      result = result + string.rep(ind, level) + 't:' + abstract_type + ' \'' + column_name + '\'\n'
    end
    level = level - 1
    result = result + string.rep(ind, level) + 'end)\n\n'
  end

  for k, v in pairs(ActiveRecord.metadata.indexes) do
    result = result + string.rep(ind, level) + '-- ' + k + '\n'
    result = result + string.rep(ind, level) + 'add_index { ' + table_to_inline(v) + ' }\n'
  end

  for k, v in pairs(ActiveRecord.metadata.references) do
    result = result + string.rep(ind, level) + '-- ' + k + '\n'
    result = result + string.rep(ind, level) + 'create_reference('
      + quote(v.table) + ', ' + quote(v.key) + ', ' + quote(v.foreign_table) + ', '
      + quote(v.foreign_key) + ', ' + tostring(v.cascade) + ')\n'
  end

  for k, v in pairs(ActiveRecord.metadata.prim_keys) do
    result = result + string.rep(ind, level) + '-- ' + k + '\n'
    result = result + string.rep(ind, level) + 'create_primary_key('
      + quote(v[1]) + ', ' + quote(v[2]) + ')\n'
  end

  result = result + '\n'

  result = result + [[
  end

  -- Metadata
  Structure.metadata = { ]]..table_to_inline(ActiveRecord.metadata)..[[ }
return Structure
]]

  return result
end
