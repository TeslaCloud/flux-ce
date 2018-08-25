class 'ActiveRecord::Model'

ActiveRecord.Model.models = {}

function ActiveRecord.Model:add(model)
  self.models[model.class_name] = model
end
