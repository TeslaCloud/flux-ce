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

  for table_name, structure in SortedPairs(ActiveRecord.schema or {}) do
    if !istable(structure) then continue end

    result = result + string.rep(ind, level) + 'create_table("' + table_name + '", function(t)\n'
    level = level + 1

    local columns_table = table.map_kv(structure, function(k, v)
      if istable(v) then
        return { column = k, id = v.id, type = v.type }
      end
    end)

    for k, data in SortedPairsByMemberValue(columns_table, 'id') do
      result = result + string.rep(ind, level) + 't:' + data.type + ' "' + data.column + '"\n'
    end
    level = level - 1
    result = result + string.rep(ind, level) + 'end)\n\n'
  end

  for k, v in SortedPairs(ActiveRecord.metadata.indexes) do
    result = result + string.rep(ind, level) + 'add_index { ' + table_to_inline(v) + ', name = "'..k..'" }\n\n'
  end

  for k, v in pairs(ActiveRecord.metadata.references) do
    local base_indent = string.rep(ind, level)
    local inner_indent = string.rep(ind, level + 1)

    result = result + base_indent + 'create_reference {\n'
      + inner_indent + 'table_name    = ' + quote(v.table) + ',\n'
      + inner_indent + 'key           = ' + quote(v.key) + ',\n'
      + inner_indent + 'foreign_table = ' + quote(v.foreign_table) + ',\n'
      + inner_indent + 'foreign_key   = ' + quote(v.foreign_key) + ',\n'
      + inner_indent + 'cascade       = ' + tostring(v.cascade) + ',\n'
      + inner_indent + 'name          = ' + quote(k)
      + '\n'..base_indent..'}\n\n'
  end

  for k, v in pairs(ActiveRecord.metadata.prim_keys) do
    result = result + string.rep(ind, level) + '-- ' + k + '\n'
    result = result + string.rep(ind, level) + 'create_primary_key('
      + quote(v[1]) + ', ' + quote(v[2]) + ')\n\n'
  end

  result = result + [[
  end

  -- Metadata
  Structure.metadata = { ]]..table_to_inline(ActiveRecord.metadata)..[[ }
return Structure
]]

  return result
end
