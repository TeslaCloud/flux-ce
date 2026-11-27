--- A species: what a character is, its body. It holds the name, description and image of the
-- species, its models by gender and their animation classes, whether its characters have a
-- gender, a name and a description of their own, the lists that random names are picked from
-- and how many characters of it one player may have. Every character has one species, chosen
-- when it is created and stored in the `species` column.
--
-- Species are defined in the files of a `species` folder of a plugin or of the schema, where
-- the object is available as SPECIES (see `Species.include_species`), and registered with
-- `Species:register`. The `Species` functions look the registered species up. Other plugins
-- read their own fields off a species, as Factions reads `default_faction`.

local isstring = isstring
local istable = istable

local stored = Species and Species.all and Species.all() or {}
local ordered = Species and Species.get_list and Species.get_list() or {}

class 'Species'

local random_name_keys = {
  [CHAR_GENDER_MALE] = 'male',
  [CHAR_GENDER_FEMALE] = 'female'
}

--- How many names `Species:get_random_name` picks before it gives up on finding one within
-- the name length limits.
const random_name_attempts = 8

--- Creates a species with default settings: the 'species.unknown.*' phrases as its name and
-- descriptions, no models, gender, name and description enabled, the 'player' animation
-- class for male and universal models and 'female' for female ones, no random names and no
-- limit on characters. Fields are left unset when no ID is given.
-- ```
-- local species = Species.new('human')
-- species.name = 'Human'
-- species.models.male = { 'models/humans/group01/male_02.mdl' }
-- species.models.female = { 'models/humans/group01/female_01.mdl' }
-- species:register()
-- ```
--
-- The other fields are optional:
-- ```
-- -- Image and sounds of the option of the species in character creation.
-- SPECIES.material = 'flux/species/human.png'
-- SPECIES.menu_sound = { 'vo/npc/male01/hi01.wav' }
-- -- Characters of the species have no gender, no name and no description of their own;
-- -- they get a random name and the phys_desc phrase.
-- SPECIES.has_gender = false
-- SPECIES.has_name = false
-- SPECIES.has_description = false
-- SPECIES.phys_desc = 'species.synth.phys_desc'
-- -- Animation class of the models of each key, see Flux.Anim#set_model_class.
-- SPECIES.model_classes = { universal = 'combine_soldier' }
-- -- Lists that random names are picked from, by 'male', 'female' and 'universal'; see
-- -- Species#get_random_name.
-- SPECIES.random_names = {
--   male = { first = { 'John', 'Paul' }, last = { 'Doe', 'Smith' } },
--   female = { first = { 'Jane', 'Mary' }, last = { 'Doe', 'Smith' } }
-- }
-- -- At most 2 characters of the species per player, 0 for no limit.
-- SPECIES.max_characters = 2
-- ```
-- @param id [String species ID, normalized with to_id]
function Species:init(id)
  if !id then return end

  self.species_id = id:to_id()
  self.name = 'species.unknown.name'
  self.description = 'species.unknown.description'
  self.phys_desc = 'species.unknown.phys_desc'
  self.material = nil
  self.menu_sound = nil
  self.has_name = true
  self.has_description = true
  self.has_gender = true
  self.models = { male = {}, female = {}, universal = {} }
  self.model_classes = { male = 'player', female = 'female', universal = 'player' }
  self.random_names = nil
  self.max_characters = 0
end

--- Returns the name of the species.
-- @return [String name or its language phrase]
function Species:get_name()
  return self.name
end

--- Returns the description of the species.
-- @return [String description or its language phrase]
function Species:get_description()
  return self.description
end

--- Returns the path of the image of the species.
-- @return [String material path, or nil if the species has no image]
function Species:get_image()
  return self.material
end

--- Returns the image of the species as a cached material. Client only.
-- @return [Material the material, or nil if the species has no image]
function Species:get_material()
  return self.material and util.get_material(self.material)
end

--- Returns the physical description that characters of the species get when the species
-- does not let players write one (has_description is false).
-- @return [String description or its language phrase]
function Species:get_phys_desc()
  return self.phys_desc
end

--- Returns how many characters of the species one player may have.
-- @return [Number 0 when there is no limit]
function Species:get_max_characters()
  return tonumber(self.max_characters) or 0
end

--- Returns all models of the species.
-- @return [Map arrays of model paths keyed by 'male', 'female' and 'universal']
function Species:get_models()
  return self.models
end

--- Returns the models of the species for a gender, falling back to the universal models when
-- the gender has none.
-- @param gender [String 'male', 'female', 'universal' or 'no_gender']
-- @return [List<String> model paths, empty when the species has none]
function Species:get_gender_models(gender)
  local models = self.models

  if gender == 'no_gender' or !istable(models[gender]) or #models[gender] == 0 then
    gender = 'universal'
  end

  return models[gender] or {}
end

--- Picks a random model of the species for a gender.
-- @param gender [String 'male', 'female', 'universal' or 'no_gender']
-- @return [String model path, nil when the species has no model for the gender]
function Species:get_random_model(gender)
  return table.Random(self:get_gender_models(gender))
end

local function pick_random_name(lists)
  local first_name = table.Random(lists.first)

  if !first_name then return end

  local last_name = lists.last and table.Random(lists.last)

  return last_name ? first_name..' '..last_name : first_name
end

--- Picks a random name from the random_names lists of the species: a first name from the
-- lists of the gender, or the 'universal' ones when the gender has none, followed by a last
-- name when those lists have last names. A character without a gender falls back to the
-- 'male' lists after the 'universal' ones. A name shorter than `characters_min_name_len` or
-- longer than `characters_max_name_len` is picked again, up to random_name_attempts times.
-- A species definition may override it to build names itself.
-- ```
-- function SPECIES:get_random_name(_gender)
--   return 'UNIT-'..math.random(100, 999)
-- end
-- ```
-- @param gender [Number CHAR_GENDER_* value]
-- @return [String the name, nil when the species has no lists for the gender or no name
--   within the length limits came up]
function Species:get_random_name(gender)
  local random_names = self.random_names

  if !istable(random_names) then return end

  local lists = random_names[random_name_keys[gender]] or random_names.universal
    or gender == CHAR_GENDER_NONE and random_names.male

  if !lists or !lists.first then return end

  local min_length = Config.get('characters_min_name_len')
  local max_length = Config.get('characters_max_name_len')

  for _ = 1, random_name_attempts do
    local name = pick_random_name(lists)

    if !name then return end

    local length = utf8.len(name)

    if length and length >= min_length and length <= max_length then
      return name
    end
  end
end

--- Registers the species under its species ID and assigns the animation class of each of its
-- models (see `Flux.Anim:set_model_class`). A species that is registered again keeps its
-- place in `Species.get_list`.
function Species:register()
  local id = self.species_id

  if !isstring(id) then return end

  if !stored[id] then
    ordered[#ordered + 1] = self
  else
    for index, species in ipairs(ordered) do
      if species.species_id == id then
        ordered[index] = self
      end
    end
  end

  stored[id] = self

  for gender, model_class in pairs(self.model_classes) do
    if isstring(model_class) then
      for _, model_path in ipairs(self:get_gender_models(gender)) do
        Flux.Anim:set_model_class(model_path, model_class)
      end
    end
  end
end

--- Returns the species registered under the exact ID.
-- @param id [String species ID]
-- @return [Species the species, or nil if it is not registered]
function Species.find_by_id(id)
  return stored[id]
end

--- Returns every registered species.
-- @return [Map species keyed by species ID]
function Species.all()
  return stored
end

--- Returns every registered species in the order in which they were first registered, which
-- puts the species of the framework before those of the schema.
-- @return [List<Species>]
function Species.get_list()
  return ordered
end

--- Finds a species by its whole ID or its whole name, ignoring letter case. The name may be
-- given as the language phrase the species is registered with or as its translation. An ID is
-- matched before any name.
-- @param name [String species ID or name]
-- @return [Species/Boolean the species, or false if no species has this ID or name]
function Species.find(name)
  if !isstring(name) then return false end

  local lowered = name:utf8lower()

  for _, species in ipairs(ordered) do
    if species.species_id:utf8lower() == lowered then
      return species
    end
  end

  for _, species in ipairs(ordered) do
    local species_name = tostring(species.name)

    if species_name:utf8lower() == lowered or t(species_name):utf8lower() == lowered then
      return species
    end
  end

  return false
end

--- Includes every file of a folder as a species definition. Each file gets the SPECIES global
-- and the species is registered once the file has run. A file whose ID is not registered yet
-- gets a fresh Species named after the file; a file whose ID is registered already gets the
-- registered species itself and amends it, so a schema changes a species of the framework
-- without replacing it.
-- ```
-- -- species/sh_human.lua of a schema: reopens the human species of the framework.
-- SPECIES.default_faction = 'citizen'
-- SPECIES.random_names = {
--   male = { first = { 'John', 'Paul' }, last = { 'Doe', 'Smith' } },
--   female = { first = { 'Jane', 'Mary' }, last = { 'Doe', 'Smith' } }
-- }
-- ```
-- @param directory [String folder to include files from]
function Species.include_species(directory)
  Pipeline.include_folder('species', directory)
end

Pipeline.register('species', function(id, file_name, _pipe)
  local existing = stored[id]

  SPECIES = (existing and existing.class == Species) ? existing : Species.new(id)

  require_relative(file_name)

  SPECIES:register()
  SPECIES = nil
end)
