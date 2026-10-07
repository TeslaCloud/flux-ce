class 'ActiveRecord::Queue'

ActiveRecord.Queue.stored = {}
ActiveRecord.Queue.types = {}

--- Records a table definition, so that the table can be created later by #run.
-- @param table_name [String]
-- @param callback [Function receives an object with a method for every column type
--   (t:string, t:integer, ...) that records the call instead of running it]
function ActiveRecord.Queue:add(table_name, callback)
  self.current_table = table_name
  callback(self.types)
end

--- Creates every table that was recorded with #add and clears the queue.
function ActiveRecord.Queue:run()
  for k, v in pairs(self.stored) do
    create_table(k, function(t)
      for k2, v2 in ipairs(v) do
        t[v2[1]](t, unpack(v2[2]))
      end
    end)
  end

  -- Purge storage once we are done.
  self.stored = {}
end

--- Registers a column type, so that it can be used in queued table definitions.
-- @param type [String abstract column type, e.g. 'string']
function ActiveRecord.Queue:add_type(type)
  self.types[type] = function(obj, ...)
    self.stored[self.current_table] = self.stored[self.current_table] or {}
    table.insert(self.stored[self.current_table], { type, { ... } })
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
