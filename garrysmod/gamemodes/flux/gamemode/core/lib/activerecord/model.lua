class 'ActiveRecord::Model'

ActiveRecord.Model.models = {}

function ActiveRecord.Model:add(model)
  self.models[model.class_name] = model
end

function ActiveRecord.Model:generate_helpers(model, column, type)
  model['find_by_'..column] = function(obj, value, callback)
    return obj:find_by(column, value, callback)
  end
end

function ActiveRecord.Model:populate()
  for k, v in pairs(self.models) do
    local schema = ActiveRecord.schema[v.table_name]
    if schema then
      for column, type in pairs(schema) do
        if !isstring(column) then continue end

        self:generate_helpers(v, column, type)
      end
    end
  end
end
