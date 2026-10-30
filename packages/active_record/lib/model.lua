--- Registry of the model classes. Every class that extends `ActiveRecord::Base` is added
-- to it automatically. Whenever the schema is restored or changed by migrations,
-- `populate` hands each model the schema of its table and gives it a `find_by_<column>`
-- shortcut for every column.

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
-- @return [Map model classes keyed by their class name]
function ActiveRecord.Model:all()
  return self.models
end

--- Adds a find_by_<column> shortcut for ActiveRecord::Base#find_by to a model class. The
-- callback of the shortcut receives the object that was found, or nil when nothing was found.
-- ```
-- ActiveRecord.Model:generate_helpers(User, 'steam_id', 'string')
--
-- User:find_by_steam_id('STEAM_0:1:12345', function(user) ... end):fetch()
-- ```
-- @param model [ActiveRecord::Base model class]
-- @param column [String column name]
-- @param _type [String abstract column type; unused]
function ActiveRecord.Model:generate_helpers(model, column, _type)
  model['find_by_'..column] = |obj, value, callback| -> obj:find_by(column, value, callback)
end

--- Hands the restored schema to every registered model and generates the
-- find_by_<column> helpers for its columns.
-- @return [ActiveRecord::Model(self)]
function ActiveRecord.Model:populate()
  for _, model in pairs(self.models) do
    local schema = ActiveRecord.schema[model.table_name]

    if schema then
      for column, data in pairs(schema) do
        if !isstring(column) or !istable(data) then continue end

        self:generate_helpers(model, column, data.type)
      end

      model.schema = schema
    end
  end

  return self
end
