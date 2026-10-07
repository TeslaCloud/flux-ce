class 'ActiveRecord::Model'

ActiveRecord.Model.models = {}

--- Adds a model class to the global list of models.
-- @param model [ActiveRecord::Base model class]
-- @return [ActiveRecord::Model(self)]
function ActiveRecord.Model:add(model)
  self.models[model.class_name] = model
  return self
end

--- Returns all registered model classes.
-- @return [Hash model classes keyed by their class name]
function ActiveRecord.Model:all()
  return self.models
end

--- Adds a find_by_<column> shortcut for ActiveRecord::Base#find_by to a model class.
-- ```
-- ActiveRecord.Model:generate_helpers(User, 'steam_id', 'string')
--
-- User:find_by_steam_id('STEAM_0:1:12345', function(user) ... end):fetch()
-- ```
-- @param model [ActiveRecord::Base model class]
-- @param column [String column name]
-- @param type [String abstract column type; unused]
function ActiveRecord.Model:generate_helpers(model, column, type)
  model['find_by_'..column] = function(obj, value, callback)
    return obj:find_by(column, value, callback)
  end
end

--- Hands the restored schema to every registered model and generates the
-- find_by_<column> helpers for its columns.
-- @return [ActiveRecord::Model(self)]
function ActiveRecord.Model:populate()
  for k, v in pairs(self.models) do
    local schema = ActiveRecord.schema[v.table_name]

    if schema then
      for column, data in pairs(schema) do
        if !isstring(column) or !istable(data) then continue end

        self:generate_helpers(v, column, data.type)
      end

      v.schema = schema
    end
  end
  return self
end
