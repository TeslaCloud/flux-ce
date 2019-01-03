function Doors:LoadData()
  self:load()
end

function Doors:SaveData()
  self:save()
end

function Doors:save()
  local doors = {}

  for k, v in ipairs(ents.get_all()) do
    if v:is_door() then
      local save_table = {
        id = v:MapCreationID()
      }

      for k1, v1 in pairs(self.properties) do
        if v1.get_save_data then
          save_table[k1] = v1.get_save_data(v)
        end
      end

      if v.conditions then
        save_table.conditions = v.conditions
      end

      table.insert(doors, save_table)
    end
  end

  data.save_plugin('doors', doors)
end

function Doors:load()
  local doors = data.load_plugin('doors', {})

  if doors then
    for k, v in pairs(doors) do
      local door = ents.GetMapCreatedEntity(v.id)

      for k1, v1 in pairs(self.properties) do
        if v1.on_load then
          v1.on_load(door, v[k1], true)
        end
      end

      door.conditions = v.conditions
    end
  end
end

cable.receive('fl_send_door_data', function(player, entity, id, data)
  Doors.properties[id].on_load(entity, data, false)
end)

cable.receive('fl_send_door_conditions', function(player, entity, conditions)
  entity.conditions = conditions
end)