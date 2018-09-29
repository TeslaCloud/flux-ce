ActiveRecord = ActiveRecord or {}

-- We only need to include ActiveRecord once.
if !ActiveRecord.Base then
  if SERVER then
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
    ActiveRecord.Base[v] = function(self) return self end
  end

  -- Walmart model definition :P
  function ActiveRecord.define_model(name)
    class(name) extends(ActiveRecord.Base)
  end
end
