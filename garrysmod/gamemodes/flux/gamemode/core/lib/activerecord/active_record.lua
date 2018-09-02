ActiveRecord.schema = ActiveRecord.schema or {}
ActiveRecord.db_settings = Settings.database[FLUX_ENV] or Settings.database['development'] or {}
ActiveRecord.adapter_name = ActiveRecord.db_settings.adapter or 'sqlite'

include 'generators.lua'
include 'database/database.lua'
include 'database/query.lua'
include 'adapters/abstract.lua'
include 'database/queue.lua'
include 'model.lua'
include 'base.lua'
include 'relation.lua'
include 'helpers.lua'
include 'commandline.lua'
include 'dumper.lua'

function ActiveRecord.add_to_schema(table_name, column_name, type)
  if !ActiveRecord.ready then
    error('Attempt to edit schema too early!')
  end
  local t = ActiveRecord.schema[table_name] or {}
  if t[column_name] then
    t[column_name] = type
  else
    local query = ActiveRecord.Database:insert('activerecord_schema')
      query:insert('table_name', table_name)
      query:insert('column_name', column_name)
      query:insert('abstract_type', type)
      query:insert('definition', ActiveRecord.adapter.types[type] or '')
    query:execute()
    t[column_name] = type
  end
  ActiveRecord.schema[table_name] = t
end

function ActiveRecord.restore_schema()
  local query = ActiveRecord.Database:select('activerecord_schema')
    query:callback(function(result, query, time)
      print_query('Schema Restore ('..time..'ms)', query)
      if istable(result) then
        for k, v in ipairs(result) do
          local t = ActiveRecord.schema[v.table_name] or {}
          t[v.column_name] = v.abstract_type
          ActiveRecord.schema[v.table_name] = t
        end
      end
      ActiveRecord.ready = true
      ActiveRecord.Model:populate()
      fl.dev_print 'ActiveRecord - Ready!'
      ActiveRecord.Queue:run()
      hook.run('ActiveRecordReady')
    end)
  query:execute()
end

function ActiveRecord.define_model(name, callback)
  local table_name = ActiveRecord.generate_table_name(name)
  local definition = function(t)
    t:primary_key 'id'
    callback(t)
    t:datetime { 'created_at', null = false }
    t:datetime { 'updated_at', null = false }
  end

  if ActiveRecord.ready then
    create_table(table_name, definition)
  else
    ActiveRecord.Queue:add(table_name, definition)
  end

  class(name) extends(ActiveRecord.Base)
end

function ActiveRecord.connect()
  local db_settings = ActiveRecord.db_settings
  local adapter = isstring(db_settings.adapter) and db_settings.adapter:lower() or 'sqlite'

  if file.Exists('flux/gamemode/core/lib/activerecord/adapters/'..adapter..'.lua', 'LUA') then
    include('flux/gamemode/core/lib/activerecord/adapters/'..adapter..'.lua')
  end

  ActiveRecord.adapter = (ActiveRecord.Adapters[adapter:capitalize()] or ActiveRecord.Adapters.Abstract).new()
  ActiveRecord.adapter:connect(db_settings)
end

function ActiveRecord.on_connected()
  fl.dev_print 'ActiveRecord - Connected to the database!'

  ActiveRecord.generate_tables()
  ActiveRecord.restore_schema()
end

function ActiveRecord.drop_schema()
  for k, v in pairs(ActiveRecord.schema) do
    drop_table(k)
  end
  drop_table 'activerecord_schema'
end

function ActiveRecord.recreate_schema()
  ActiveRecord.drop_schema()

  timer.Simple(0.25, function()
    ActiveRecord.generate_tables()
    
    print 'Done! Restarting...'

    timer.Simple(0.5, function()
      RunConsoleCommand('changelevel', game.GetMap())
    end)
  end)
end
