-- We only need to include ActiveRecord once.
if !ActiveRecord.Base then
  if SERVER then
    AddCSLuaFile()
    AddCSLuaFile 'base.lua'
    return include 'active_record.lua'
  end

  -- Client hacks

  include 'base.lua'

  local remove_keys = {
    'class_extended', 'dump','where', 'where_not',
    'first','last','all','order','find','find_by',
    'limit', '_process_child',  '_fetch_relation',
    'run_query','expect','get','rescue','destroy',
    'save','has','has_many','has_one','belongs_to'
  }

  for k, v in ipairs(remove_keys) do
    --- Clientside stub that replaces a serverside-only method. Does nothing.
    -- @param self [ActiveRecord::Base]
    -- @return [ActiveRecord::Base(self)]
    ActiveRecord.Base[v] = function(self) return self end
  end

  --- Clientside stand-in for model definition. Only declares a class that extends
  -- ActiveRecord::Base, no database table is involved.
  -- @param name [String class name of the model]
  function ActiveRecord.define_model(name)
    class(name) extends(ActiveRecord.Base)
  end
end
