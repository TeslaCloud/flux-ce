class 'Faction'

function Faction:init(id)
  if !id then return end

  self.faction_id = id:to_id()
  self.name = 'Unknown Faction'
  self.print_name = nil
  self.description = 'This faction has no description set!'
  self.phys_desc = 'This faction has no default physical description set!'
  self.whitelisted = false
  self.default_class = nil
  self.color = Color(255, 255, 255)
  self.material = nil
  self.has_name = true
  self.has_description = true
  self.has_gender = true
  self.models = { male = {}, female = {}, universal = {} }
  self.classes = {}
  self.rank = {}
  self.data = {}
  self.name_template = '{rank} {name}'
  -- You can also use {data:key} to insert data
  -- set via Faction:set_data.
end

function Faction:get_name()
  return self.name
end

function Faction:get_color()
  return self.color
end

function Faction:get_material()
  return self.material and util.get_material(self.material)
end

function Faction:get_image()
  return self.material
end

function Faction:get_name()
  return self.name
end

function Faction:get_data(key)
  return self.data[key]
end

function Faction:get_description()
  return self.description
end

function Faction:get_ranks()
  return self.rank
end

function Faction:get_rank(number)
  return self.rank[number]
end

function Faction:add_class(id, class_name, description, color, callback)
  if !id then return end

  self.classes[id] = {
    name = class_name,
    description = description,
    color = color,
    callback = callback
  }
end

function Faction:add_rank(id, name_filter)
  if !id then return end

  if !name_filter then name_filter = id end

  table.insert(self.rank, {
    id = id,
    name = name_filter
  })
end

function Faction:generate_name(player, char_name, rank, default_data)
  default_data = default_data or {}

  if hook.run('ShouldNameGenerate', player, self, char_name, rank, default_data) == false then return player:name() end

  if isfunction(self.MakeName) then
    return self:MakeName(player, char_name, rank, default_data) or 'John Doe'
  end

  local final_name = self.name_template

  if final_name:find('{name}') then
    final_name = final_name:Replace('{name}', char_name or '')
  end

  if final_name:find('{rank}') then
    for k, v in ipairs(self.rank) do
      if v.id == rank or k == rank then
        final_name = final_name:Replace('{rank}', v.name)

        break
      end
    end
  end

  local assistants = string.find_all(final_name, '{[%w]+:[%w]+}')

  for k, v in ipairs(assistants) do
    v = v[1]

    if v:starts('{callback:') then
      local func_name = v:utf8sub(11, utf8.len(v) - 1)
      local callback = self[func_name]

      if isfunction(callback) then
        final_name = final_name:Replace(v, callback(self, player))
      end
    elseif v:starts('{data:') then
      local key = v:utf8sub(7, utf8.len(v) - 1)
      local data = player:get_character_data(key, (default_data[key] or self.data[key] or ''))

      if isstring(data) then
        final_name = final_name:Replace(v, data)
      end
    end
  end

  return final_name
end

function Faction:set_data(key, value)
  key = tostring(key)

  if !key then return end

  self.data[key] = tostring(value)
end

function Faction:on_player_join(player)
end

function Faction:on_player_leave(player)
end

function Faction:register()
  faction.register(self.faction_id, self)
end
