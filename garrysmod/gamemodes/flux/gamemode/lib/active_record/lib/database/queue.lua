class 'ActiveRecord::Queue'

ActiveRecord.Queue.stored = {}
ActiveRecord.Queue.types = {}

function ActiveRecord.Queue:add(table_name, callback)
  self.current_table = table_name
  callback(self.types)
end

function ActiveRecord.Queue:run()
  for k, v in pairs(self.stored) do
    create_table(k, function(t)
      for k2, v2 in ipairs(v) do
        t[v2[1]](t, unpack(v2[2]))
      end
    end)
  end
end

function ActiveRecord.Queue:add_type(type)
  self.types[type] = function(obj, ...)
    self.stored[self.current_table] = self.stored[self.current_table] or {}
    table.insert(self.stored[self.current_table], { type, {...} })
  end
end

ActiveRecord.Queue:add_type 'primary_key'
ActiveRecord.Queue:add_type 'string'
ActiveRecord.Queue:add_type 'text'
ActiveRecord.Queue:add_type 'integer'
ActiveRecord.Queue:add_type 'float'
ActiveRecord.Queue:add_type 'decimal'
ActiveRecord.Queue:add_type 'datetime'
ActiveRecord.Queue:add_type 'timestamp'
ActiveRecord.Queue:add_type 'time'
ActiveRecord.Queue:add_type 'date'
ActiveRecord.Queue:add_type 'binary'
ActiveRecord.Queue:add_type 'boolean'
ActiveRecord.Queue:add_type 'json'
