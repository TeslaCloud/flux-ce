class 'ActiveRecord::Schema' extends 'ActiveRecord::Migration'

function ActiveRecord.Schema:init(version)
  self.version = version
end

function ActiveRecord.Schema:define(version)
  return self.new(version)
end

function ActiveRecord.Schema:create_tables()
  return self
end
