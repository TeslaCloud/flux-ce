--- Entry point of the ActiveRecord package, loaded on both the server and the client.
-- The server loads the whole library from here. The client only receives
-- `ActiveRecord::Base`, with every method that needs the database replaced by a stub that
-- returns the object, and an `ActiveRecord.define_model` that merely declares a class, so
-- that model files can be loaded on the client, where there is no database.

if !ActiveRecord.Base then
  if SERVER then
    AddCSLuaFile()
    AddCSLuaFile 'base.lua'
    return include 'active_record.lua'
  end

  include 'base.lua'

  local remove_keys = {
    'class_extended', 'dump', 'where', 'where_not',
    'first', 'last', 'all', 'order', 'find', 'find_by',
    'limit', 'skip', 'preload', '_process_child', '_fetch_relations',
    'load_relations', 'run_query', 'expect', 'get', 'fetch', 'rescue',
    'update_all', 'delete_all', 'destroy', 'save', 'has', 'has_many',
    'has_one', 'belongs_to'
  }

  for _, method_name in ipairs(remove_keys) do
    --- Clientside stub that replaces a serverside-only method. Does nothing.
    -- @param self [ActiveRecord::Base]
    -- @return [ActiveRecord::Base(self)]
    ActiveRecord.Base[method_name] = self -> self
  end

  --- Clientside stand-in for model definition. Only declares a class that extends
  -- ActiveRecord::Base, no database table is involved.
  -- @param name [String class name of the model]
  function ActiveRecord.define_model(name)
    class(name) extends(ActiveRecord.Base)
  end
end
