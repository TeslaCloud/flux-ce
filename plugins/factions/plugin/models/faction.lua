class 'Faction'

--- Creates a faction with default settings: no ranks, no models, name, description and gender
-- enabled, and the '{rank} {name}' name template. Fields are left unset when no ID is given.
-- ```
-- local faction = Faction.new('citizen')
-- faction.name = 'Citizen'
-- faction.has_description = false
-- faction.models.male = { 'models/humans/group01/male_02.mdl' }
-- faction.models.female = { 'models/humans/group01/female_01.mdl' }
-- faction:add_rank('citizen', 'Mr.')
-- faction:register()
-- ```
-- @param id [String faction ID, normalized with to_id]
function Faction:init(id)
  if !id then return end

  self.faction_id = id:to_id()
  self.name = 'Unknown Faction'
  self.description = 'This faction has no description set!'
  self.phys_desc = 'This faction has no default physical description set!'
  self.whitelisted = false
  self.default_class = nil
  self.color = Color(255, 255, 255)
  self.material = nil
  self.has_name = true
  self.has_description = true
  self.has_gender = true
  self.model_classes = { male = 'player', female = 'player', universal = 'player'}
  self.models = { male = {}, female = {}, universal = {} }
  self.rank = {}
  self.data = {}
  self.name_template = '{rank} {name}'
  -- You can also use {data:key} to insert data
  -- set via Faction:set_data.
end

--- Returns the name of the faction.
-- @return [String]
function Faction:get_name()
  return self.name
end

--- Returns the team color of the faction.
-- @return [Color]
function Faction:get_color()
  return self.color
end

--- Returns the faction's image as a cached material. Client only.
-- @return [Material the material, or nil if the faction has no image]
function Faction:get_material()
  return self.material and util.get_material(self.material)
end

--- Returns the path of the faction's image.
-- @return [String material path, or nil if the faction has no image]
function Faction:get_image()
  return self.material
end

--- Returns the name of the faction.
-- @return [String]
function Faction:get_name()
  return self.name
end

--- Returns a value stored with set_data.
-- @param key [String]
-- @return [String the stored value, or nil if nothing is stored under the key]
function Faction:get_data(key)
  return self.data[key]
end

--- Returns the description of the faction.
-- @return [String]
function Faction:get_description()
  return self.description
end

--- Returns the ranks of the faction, lowest first.
-- @return [List<Map> rank tables with id and name fields]
function Faction:get_ranks()
  return self.rank
end

--- Returns a rank of the faction by its position.
-- @param number [Number rank index, 1 being the lowest]
-- @return [Map rank table with id and name fields, or nil if there is no such rank]
function Faction:get_rank(number)
  return self.rank[number]
end

--- Returns the ID of a rank of the faction. Errors if there is no rank at that position.
-- @param number [Number rank index, 1 being the lowest]
-- @return [String rank ID]
function Faction:get_rank_name(number)
  return self:get_rank(number).id
end

--- Returns all models of the faction.
-- @return [Map arrays of model paths keyed by 'male', 'female' and 'universal']
function Faction:get_models()
  return self.models
end

--- Returns the models of the faction for a gender, falling back to the universal models when
-- the gender has none.
-- @param gender [String 'male', 'female', 'universal' or 'no_gender']
-- @return [List<String> model paths]
function Faction:get_gender_models(gender)
  local faction_models = self:get_models()

  if gender == 'no_gender' or !faction_models[gender] or #faction_models[gender] == 0 then
    gender = 'universal'
  end

  return faction_models[gender]
end

--- Picks a random faction model that matches the player's gender.
-- @param target [Player]
-- @return [String model path]
function Faction:get_random_model(target)
  return table.random(self:get_gender_models(target:get_gender()))
end

--- Adds a rank above the ranks added so far.
-- @param id [String rank ID; nothing is added when it is nil]
-- @param name_filter=id [String text that replaces {rank} in generated names]
function Faction:add_rank(id, name_filter)
  if !id then return end

  if !name_filter then name_filter = id end

  table.insert(self.rank, {
    id = id,
    name = name_filter
  })
end

--- Builds a character name for a player from the faction's name template, which may contain
-- {name}, {rank}, {data:key} and {callback:method} placeholders. A faction that defines
-- make_name(target, char_name, rank, default_data) bypasses the template.
-- ```
-- FACTION.name_template = '{data:unit} {rank} {name}'
-- FACTION:set_data('unit', 'C17')
-- FACTION:add_rank('officer', 'Ofc.')
--
-- -- For a player named 'John Doe':
-- FACTION:generate_name(target, 'officer') -- 'C17 Ofc. John Doe'
-- ```
-- @param target [Player]
-- @param rank [Number/String rank index or rank ID used for {rank}]
-- @param default_data=nil [Map values for {data:key} that override the faction's own data]
-- @return [String the generated name; the player's current name if a ShouldNameGenerate
--   hook returns false]
function Faction:generate_name(target, rank, default_data)
  local char_name = target:name()

  default_data = default_data or {}

  if hook.run('ShouldNameGenerate', target, self, char_name, rank, default_data) == false then return target:name() end

  if isfunction(self.make_name) then
    return self:make_name(target, char_name, rank, default_data) or 'John Doe'
  end

  local final_name = self.name_template

  if final_name:find('{name}') then
    final_name = final_name:Replace('{name}', char_name or '')
  end

  if final_name:find('{rank}') then
    for k, v in ipairs(self.rank) do
      if v.id == rank or k == rank then
        final_name = final_name:replace('{rank}', v.name)

        break
      end
    end
  end

  local helpers = string.find_all(final_name, '{([%w_]+):([%w_]+)}')

  for k, v in ipairs(helpers) do
    local m1, m2 = v.matches[1], v.matches[2]

    if m1 == 'callback' then
      local callback = self[m2]

      if isfunction(callback) then
        final_name = final_name:replace(v.text, callback(self, target))
      end
    elseif m1 == 'data' then
      local data = default_data[m2] or self.data[m2] or ''

      if isstring(data) then
        final_name = final_name:replace(v.text, data)
      end
    end
  end

  return final_name
end

--- Stores a value on the faction for use as {data:key} in the name template. Both the key
-- and the value are converted to strings.
-- @param key [Any]
-- @param value [Any]
function Faction:set_data(key, value)
  key = tostring(key)

  if !key then return end

  self.data[key] = tostring(value)
end

--- Called on the server when a player is moved into this faction. Does nothing by default;
-- override it in the faction definition.
-- @param target [Player]
function Faction:on_player_join(target)
end

--- Called on the server when a player is moved out of this faction. Does nothing by default;
-- override it in the faction definition.
-- @param target [Player]
function Faction:on_player_leave(target)
end

--- Registers the faction under its faction ID.
-- @see [Factions.add_faction]
function Faction:register()
  Factions.add_faction(self.faction_id, self)
end
