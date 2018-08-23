ActiveRecord = ActiveRecord or {}
ActiveRecord.schema = ActiveRecord.schema or { _restored = false }
ActiveRecord.db_settings = Settings.database[FLUX_ENV] or Settings.database['development'] or {}
ActiveRecord.adapter_name = ActiveRecord.db_settings.adapter or 'sqlite'

include 'generators.lua'
include 'database/database.lua'
include 'database/query.lua'
include 'adapters/abstract.lua'

function ActiveRecord.add_to_schema(table_name, column_name, type)
  if !ActiveRecord.schema._restored then
    error('Attempt to edit schema too early!')
  end
  local t = ActiveRecord.schema[table_name] or {}
  if t[column_name] then
    t[column_name] = type
  else
    local query = ActiveRecord.Database:insert('activerecord_schema')
      query:insert('name', column_name)
      query:insert('abstract_type', type)
      query:insert('definition', ActiveRecord.adapter.types[type] or '')
    query:execute()
    t[column_name] = type
  end
  ActiveRecord.schema[table_name] = t
end

function ActiveRecord.restore_schema()
  local query = ActiveRecord.Database:select('activerecord_schema')
    query:callback(function(result)
      for k, v in ipairs(result) do
        ActiveRecord.schema[v.name] = v.abstract_type
      end
      ActiveRecord.schema._restored = true
      hook.Run('activerecord_ready')
    end)
  query:execute()
end

function ActiveRecord.define_model(name, callback)
  create_table(ActiveRecord.generate_table_name(name), function(t)
    t:primary_key 'id'
    callback(t)
    t:timestamp { 'created_at', null = false }
    t:timestamp { 'updated_at', null = false }
  end)
  class(name) extends(ActiveRecord.Base)
end

function ActiveRecord.connect()
  local db_settings = ActiveRecord.db_settings
  local adapter = isstring(db_settings.adapter) and db_settings.adapter:lower() or 'sqlite'

  if file.Exists('flux/gamemode/core/lib/activerecord/adapters/'..adapter..'.lua')
    include('adapters/'..adapter..'.lua')
  end

  ActiveRecord.adapter = (ActiveRecord.Adapters[adapter:capitalize()] or ActiveRecord.Adapters.Abstract).new()
  ActiveRecord.adapter:connect(db_settings)
end

function ActiveRecord.on_connected()
  ActiveRecord.create_tables()
  ActiveRecord.restore_schema()
end

include 'base.lua'
include 'relation.lua'
include 'helpers.lua'
