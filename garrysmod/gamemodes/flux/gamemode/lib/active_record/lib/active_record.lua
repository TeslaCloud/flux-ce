ActiveRecord.schema = ActiveRecord.schema or {}
ActiveRecord.metadata = ActiveRecord.metadata or {
  indexes = {},
  references = {},
  prim_keys = {},
  adapter = '', db_name = ''
}
ActiveRecord.db_settings = DatabaseSettings[FLUX_ENV] or DatabaseSettings['development'] or {}
ActiveRecord.adapter_name = ActiveRecord.db_settings.adapter or 'sqlite'

include 'generators/generator.lua'
include 'database/database.lua'
include 'database/query.lua'
include 'adapters/abstract.lua'
include 'database/queue.lua'
include 'migrator/migrator.lua'
include 'model.lua'
include 'validator.lua'
include 'base.lua'
include 'relation.lua'
include 'helpers.lua'
include 'commandline.lua'
include 'dumper.lua'

function ActiveRecord.add_to_schema(table_name, column_name, type)
  if !ActiveRecord.ready then
    error('Attempt to edit schema too early!')
  end
  local t = ActiveRecord.schema[table_name] or { last_id = 0 }
  if t[column_name] then
    t[column_name] = { id = t[column_name].id, type = type }
  else
    local query = ActiveRecord.Database:insert('ar_schema')
      query:insert('table_name', table_name)
      query:insert('column_name', column_name)
      query:insert('abstract_type', type)
      query:insert('definition', ActiveRecord.adapter.types[type] or '')
    query:execute()
    t.last_id = t.last_id + 1
    t[column_name] = { id = t.last_id, type = type }
  end
  ActiveRecord.schema[table_name] = t
end

function ActiveRecord.restore_schema()
  local query = ActiveRecord.Database:select('ar_schema')
    query:callback(function(result, query, time)
      print_query('Schema Restore ('..time..'s)', query)

      if istable(result) then
        for k, v in ipairs(result) do
          local t = ActiveRecord.schema[v.table_name] or { last_id = 0 }
          v.id = tonumber(v.id) or 0
          t[v.column_name] = { id = v.id, type = v.abstract_type }
          if t.last_id < v.id then
            t.last_id = v.id
          end
          ActiveRecord.schema[v.table_name] = t
        end
      end

      ActiveRecord.ready = true
      ActiveRecord.Model:populate()
      Flux.dev_print 'ActiveRecord - Ready!'
      ActiveRecord.Queue:run()
    end)
  query:execute()
end

-- Make sure to run this while the adapter is in "sync mode"
function ActiveRecord.get_meta_key(key, default)
  local query = ActiveRecord.Database:select('ar_metadata')
    query:where('key', key)
    query:limit(1)
    query:callback(function(res, query_str, time)
      print_query('Meta Get ('..time..'s)', query_str)
      if istable(res) and #res > 0 then
        return res[1] and res[1].value or default
      end
      return default
    end)
  return query:execute()
end

function ActiveRecord.set_meta_key(key, value)
  local query = ActiveRecord.Database:select('ar_metadata')
    query:where('key', key)
    query:callback(function(res)
      if istable(res) and #res > 0 then
        local q = ActiveRecord.Database:update('ar_metadata')
          q:where('key', key)
          q:update('value', value)
          q:callback(function(r, query_str, time)
            print_query('Meta Update ('..time..'s)', query_str)
          end)
        q:execute()
      else
        local q = ActiveRecord.Database:insert('ar_metadata')
          q:insert('key', key)
          q:insert('value', value)
          q:callback(function(r, query_str, time)
            print_query('Meta Insert ('..time..'s)', query_str)
          end)
        q:execute()
      end
    end)
  query:execute()
end

function ActiveRecord.define_model(name, callback)
  local definition = function(t)
    t:primary_key 'id'
    callback(t)
    t:datetime { 'created_at', null = false }
    t:datetime { 'updated_at', null = false }
  end

  if ActiveRecord.ready then
    create_table(name, definition)
  else
    ActiveRecord.Queue:add(name, definition)
  end
end

function ActiveRecord.connect()
  local db_settings = ActiveRecord.db_settings
  local adapter = isstring(db_settings.adapter) and db_settings.adapter:lower() or 'sqlite'

  if file.Exists('flux/gamemode/lib/active_record/lib/adapters/'..adapter..'.lua', 'LUA') then
    include('flux/gamemode/lib/active_record/lib/adapters/'..adapter..'.lua')
  end

  ActiveRecord.adapter = (ActiveRecord.Adapters[adapter:capitalize()] or ActiveRecord.Adapters.Abstract).new()
  ActiveRecord.adapter:connect(db_settings, ActiveRecord.Adapters.Abstract.on_connected)
end

function ActiveRecord.on_connected()
  Flux.dev_print 'ActiveRecord - Connected to the database!'

  ActiveRecord.generate_tables()
  ActiveRecord.restore_schema()

  local class_name = ActiveRecord.adapter.class_name:lower()
  local db_version = ActiveRecord.get_meta_key('version', 0)
  local adapter = ActiveRecord.get_meta_key('adapter', class_name)

  if adapter != class_name then
    ActiveRecord.drop_schema(true)
    ActiveRecord.generate_tables()

    adapter = class_name
  end

  ActiveRecord.migrator = ActiveRecord.Migrator.new(db_version)
  ActiveRecord.migrator:run_migrations()

  ActiveRecord.set_meta_key('version', ActiveRecord.migrator.schema.version)
  ActiveRecord.set_meta_key('adapter', adapter)

  hook.run('ActiveRecordReady')
end

function ActiveRecord.drop_schema(meta_only)
  if !meta_only then
    for k, v in pairs(ActiveRecord.schema) do
      drop_table(k)
    end
  end
  drop_table 'ar_schema'
  drop_table 'ar_metadata'
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

Pipeline.register('migrations', function(id, file_name, pipe)
  if file_name:ends('.lua') then
    ActiveRecord.Migrator:add_file(file_name)
  end
end)
