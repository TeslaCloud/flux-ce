class 'ActiveRecord::Migration'

function ActiveRecord.Migration:init(version)
  self.version = version or 0
  return self
end

function ActiveRecord.Migration:change()
  return self
end

function ActiveRecord.Migration:up()
  self:change()
  return self
end

function ActiveRecord.Migration:down()
  return self
end
