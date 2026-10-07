class 'ActiveRecord::Schema' extends 'ActiveRecord::Migration'

--- Creates a schema definition.
-- @param version [Number/String schema version]
function ActiveRecord.Schema:init(version)
  self.version = version
end

--- Creates a new schema definition. Used by the generated 'db/schema.lua' file.
-- ```
-- local Structure = ActiveRecord.Schema:define(20190309120000)
--   function Structure:create_tables()
--     create_table('users', function(t)
--       t:primary_key 'id'
--       t:string 'steam_id'
--     end)
--   end
-- return Structure
-- ```
-- @param version [Number/String schema version]
-- @return [ActiveRecord::Schema]
function ActiveRecord.Schema:define(version)
  return ActiveRecord.Schema.new(version)
end

--- Creates all tables of the schema. Does nothing by default; the generated schema
-- file overrides it.
-- @return [ActiveRecord::Schema(self)]
function ActiveRecord.Schema:create_tables()
  return self
end

--- Creates foreign keys with cascading deletion for the relations of every model.
-- On SQLite only the indexes are created.
function ActiveRecord.Schema:setup_references()
  local references = {}
  local is_sqlite = ActiveRecord.adapter_name == 'sqlite'

  for key, model in pairs(ActiveRecord.Model:all()) do
    for k, v in ipairs(model.relations) do
      if !v.child then
        references[v.table_name] = references[v.table_name] or {}
        references[v.table_name][v.column_name] = model.table_name
      end
    end
  end

  for k, v in pairs(references) do
    for k2, v2 in pairs(v) do
      if !is_sqlite then
        create_reference({ table_name = k, key = k2, foreign_table = v2, foreign_key = 'id', cascade = true })
      else
        add_index { k, k2 } -- only add index if SQLite
      end
    end
  end
end
