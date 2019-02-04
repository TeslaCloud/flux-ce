--[[
  mysql - 2.0.0
  A simple Database wrapper for Garry's Mod.

  Alexander Grist-Hucker
  http://www.alexgrist.com

  Meow the Cat
  https://teslacloud.net
--]]

class 'ActiveRecord::Database'

function ActiveRecord.Database:select(table_name)
  return ActiveRecord.Query.new(table_name, 'select')
end

function ActiveRecord.Database:insert(table_name)
  return ActiveRecord.Query.new(table_name, 'insert')
end

function ActiveRecord.Database:update(table_name)
  return ActiveRecord.Query.new(table_name, 'update')
end

function ActiveRecord.Database:delete(table_name)
  return ActiveRecord.Query.new(table_name, 'delete')
end

function ActiveRecord.Database:drop(table_name)
  return ActiveRecord.Query.new(table_name, 'drop')
end

function ActiveRecord.Database:truncate(table_name)
  return ActiveRecord.Query.new(table_name, 'truncate')
end

function ActiveRecord.Database:create(table_name)
  return ActiveRecord.Query.new(table_name, 'create')
end

function ActiveRecord.Database:change(table_name)
  return ActiveRecord.Query.new(table_name, 'change')
end

timer.Create('ActiveRecord::Database#think', 1, 0, function()
  ActiveRecord.adapter:think()
end)
