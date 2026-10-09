--- A faction that characters can belong to.
-- It holds the name, description, color and image of the faction, its models by gender, its
-- ranks from the lowest to the highest, and the template that character names are generated
-- from. It can also limit how many of its members may be online at once and how many
-- characters one player may have in it, give its members weapons, maximum health and armor
-- when they spawn, and set how the NPCs of the map feel about them. A rank can carry a
-- model, weapons, maximum health and armor of its own, a limit, the right to promote and
-- demote other members, and the mark of the rank that new members start with.
--
-- Factions are normally defined in the files of a factions folder, where the object is
-- available as FACTION (see `Factions.include_factions`), and are registered with
-- `Faction:register`. A definition can override `Faction:on_player_join`,
-- `Faction:on_player_leave`, `Faction:on_character_create` and `Faction:can_transfer`, and
-- define make_name to build names itself. Unlike the other files of the models folder, this
-- is a plain class that is not stored in the database.

class 'Faction'

local disposition_hate = D_HT or 1
local disposition_fear = D_FR or 2
local disposition_like = D_LI or 3
local disposition_neutral = D_NU or 4

local dispositions = {
  hate = disposition_hate,
  fear = disposition_fear,
  like = disposition_like,
  neutral = disposition_neutral
}

--- Creates a faction with default settings: no ranks, no models, no limits, no loadout, name,
-- description and gender enabled, and the '{rank} {name}' name template, which may also
-- contain {data:key} to insert a value set with `Faction:set_data`. Fields are left unset
-- when no ID is given.
-- ```
-- local faction = Faction.new('citizen')
-- faction.name = 'Citizen'
-- faction.has_description = false
-- faction.phys_desc = 'Wearing the worn out blue uniform of a citizen.'
-- faction.models.male = { 'models/humans/group01/male_02.mdl' }
-- faction.models.female = { 'models/humans/group01/female_01.mdl' }
-- faction:add_rank('citizen', 'Mr.')
-- faction:register()
-- ```
--
-- The fields that limit and equip the members are all optional:
-- ```
-- -- At most 8 members online at once, and 2 characters of the faction per player.
-- FACTION.limit = 8
-- FACTION.max_characters = 2
-- -- Given on every spawn on top of the default loadout.
-- FACTION.loadout = { 'weapon_stunstick' }
-- -- Maximum health and armor of the members, who spawn with both of them full.
-- FACTION.max_health = 100
-- FACTION.max_armor = 50
-- -- 'like', 'hate', 'fear', 'neutral' or a D_* value for each NPC class.
-- FACTION.npc_relations = {
--   npc_metropolice = 'like',
--   npc_citizen = 'fear'
-- }
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
  self.model_classes = { male = 'player', female = 'player', universal = 'player' }
  self.models = { male = {}, female = {}, universal = {} }
  self.rank = {}
  self.data = {}
  self.name_template = '{rank} {name}'
  self.limit = 0
  self.max_characters = 0
  self.loadout = {}
  self.max_health = nil
  self.max_armor = nil
  self.npc_relations = {}
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

--- Returns the physical description that characters of the faction get when the faction
-- does not let players write one (has_description is false).
-- @return [String description or its language phrase]
function Faction:get_phys_desc()
  return self.phys_desc
end

--- Returns the ranks of the faction, lowest first.
-- @return [List<Map> rank tables with id and name fields, and the optional fields described
--   at `Faction:add_rank`]
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

--- Finds a rank of the faction by its position or by its ID.
-- ```
-- local index, rank_table = faction_table:find_rank('officer')
-- ```
-- @param rank [Number/String rank index, or rank ID, whose letter case is ignored]
-- @return [Number rank index and Map rank table, or nothing if there is no such rank]
function Faction:find_rank(rank)
  if isnumber(rank) then
    local rank_table = self.rank[rank]

    if rank_table then
      return rank, rank_table
    end

    return
  end

  if !isstring(rank) then return end

  local lowered = rank:utf8lower()

  for k, v in ipairs(self.rank) do
    if v.id:utf8lower() == lowered then
      return k, v
    end
  end
end

--- Returns the rank that new members of the faction start with: the first rank that was
-- added with the default field set, or else the lowest rank.
-- @return [Number rank index; 1 as well when the faction has no ranks]
function Faction:get_default_rank()
  for k, v in ipairs(self.rank) do
    if v.default then
      return k
    end
  end

  return 1
end

--- Returns the model that holders of a rank use instead of the model of their character.
-- The model field of a rank is either a single path, or a table of paths keyed by 'male',
-- 'female', 'no_gender' and 'universal', the last one being the fallback for a gender that
-- has no path of its own.
-- @param rank [Number rank index]
-- @param gender [String 'male', 'female' or 'no_gender', as `Player:get_gender` returns it]
-- @return [String model path, or nil if the rank does not change the model]
function Faction:get_rank_model(rank, gender)
  local rank_table = rank != nil and self.rank[rank]
  local model = rank_table and rank_table.model

  if istable(model) then
    model = model[gender] or model.universal
  end

  if isstring(model) and model != '' then
    return model
  end
end

--- Returns the weapons that members of the faction are given when they spawn, in addition
-- to the default loadout: the loadout of the faction followed by that of the rank.
-- @param rank=nil [Number rank index of the member; only the loadout of the faction is
--   returned without it]
-- @return [List<String> weapon classes, each one once]
function Faction:get_loadout(rank)
  local loadout = {}
  local rank_table = rank != nil and self.rank[rank]

  if istable(self.loadout) then
    for k, v in ipairs(self.loadout) do
      if !table.HasValue(loadout, v) then
        table.insert(loadout, v)
      end
    end
  end

  if rank_table and istable(rank_table.loadout) then
    for k, v in ipairs(rank_table.loadout) do
      if !table.HasValue(loadout, v) then
        table.insert(loadout, v)
      end
    end
  end

  return loadout
end

--- Returns the maximum health of the members of the faction: that of the rank if the rank
-- sets one, otherwise that of the faction.
-- @param rank=nil [Number rank index of the member]
-- @return [Number maximum health, or nil if neither the rank nor the faction sets one]
function Faction:get_max_health(rank)
  local rank_table = rank != nil and self.rank[rank]

  return rank_table and tonumber(rank_table.max_health) or tonumber(self.max_health)
end

--- Returns the maximum armor of the members of the faction: that of the rank if the rank
-- sets one, otherwise that of the faction.
-- @param rank=nil [Number rank index of the member]
-- @return [Number maximum armor, or nil if neither the rank nor the faction sets one]
function Faction:get_max_armor(rank)
  local rank_table = rank != nil and self.rank[rank]

  return rank_table and tonumber(rank_table.max_armor) or tonumber(self.max_armor)
end

--- Returns how NPCs of a class feel about the members of the faction, as set in the
-- npc_relations field of the faction. The result is the number of the D_* value, also where
-- the game does not define these globals.
-- @param npc_class [String entity class of the NPC, such as 'npc_metropolice']
-- @return [Number D_HT, D_FR, D_LI or D_NU, or nil if the faction does not change the
--   feelings of that class or the value it gives is not a disposition]
function Faction:get_npc_disposition(npc_class)
  local value = istable(self.npc_relations) and self.npc_relations[npc_class]

  if isstring(value) then
    value = dispositions[value:lower()]
  end

  if isnumber(value) and value >= disposition_hate and value <= disposition_neutral then
    return value
  end
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
  return table.Random(self:get_gender_models(target:get_gender()))
end

--- Adds a rank above the ranks added so far. Besides its ID and the text it puts into
-- names, a rank can carry optional fields:
-- * `model`: model that holders of the rank use instead of the model of their character,
--   either a path or a table of paths keyed by 'male', 'female', 'no_gender' and 'universal'.
-- * `model_class`: animation class of that model (see `Flux.Anim:set_model_class`); for a
--   table of models it defaults to the model class the faction has for the same key.
-- * `loadout`: List<String> of weapon classes given on spawn on top of those of the faction.
-- * `max_health`, `max_armor`: replace the maximum health and armor of the faction.
-- * `limit`: how many holders of the rank may be online at once, 0 or nil for no limit.
-- * `default`: true makes it the rank that new members of the faction start with.
-- * `can_promote`: the highest rank a holder may promote other members to, as a rank index
--   or a rank ID; true stands for the rank right below their own.
-- * `can_demote`: the highest rank a holder may demote other members from, in the same form.
-- ```
-- FACTION:add_rank('recruit', 'Rct.', { default = true })
-- FACTION:add_rank('officer', 'Ofc.', { loadout = { 'weapon_pistol' }, max_armor = 50 })
-- FACTION:add_rank('sergeant', 'Sgt.', {
--   model = 'models/police_sergeant.mdl',
--   limit = 2,
--   can_promote = 'officer',
--   can_demote = 'officer'
-- })
-- ```
-- @param id [String rank ID; nothing is added when it is nil]
-- @param name_filter=id [String/Map text that replaces {rank} in generated names. A table
--   is taken as the data argument, and its name field as the text]
-- @param data=nil [Map optional fields of the rank; the table itself becomes the rank table]
-- @return [Map the rank table, or nil if nothing was added]
function Faction:add_rank(id, name_filter, data)
  if !id then return end

  if istable(name_filter) then
    data = name_filter
    name_filter = nil
  end

  local rank_table = istable(data) and data or {}

  rank_table.id = id
  rank_table.name = name_filter or rank_table.name or id

  table.insert(self.rank, rank_table)

  return rank_table
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

  --- Decides whether a character name is generated for a player. Called by
  -- `Faction:generate_name` before the name template of the faction is applied; the Factions
  -- plugin itself returns false for bots.
  -- @param target [Player]
  -- @param faction [Faction the faction that generates the name]
  -- @param char_name [String the current name of the player]
  -- @param rank [Number/String rank index or rank ID the name is generated for]
  -- @param default_data [Map values for the {data:key} placeholders of the template]
  -- @return [Boolean return false to keep the current name of the player]
  if hook.Run('ShouldNameGenerate', target, self, char_name, rank, default_data) == false then return target:name() end

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

--- Called on the server when a character of this faction is about to be created, after the
-- creation data has passed the checks of the Characters and Factions plugins. The callback
-- may change the data in place, for instance to set the rank the character starts with, and
-- may refuse the character. Does nothing by default; override it in the faction definition.
-- ```
-- function FACTION:on_character_create(owner, data)
--   if #Factions.get_players(self.faction_id) == 0 then
--     data.rank = self:find_rank('sergeant')
--   end
-- end
-- ```
-- @param owner [Player the player the character is created for]
-- @param data [Map creation data: name, phys_desc, gender (a CHAR_GENDER_* value), model,
--   skin and faction; rank and char_class may be set]
-- @return [Boolean/Number return false to refuse the character, optionally followed by a
--   String language phrase that tells the player why and a Map of its arguments; or return
--   a CHAR_ERR_* code to refuse it with the text of that code]
function Faction:on_character_create(owner, data)
end

--- Called on the server when `Factions.can_transfer` checks whether a player may be moved
-- into this faction, as the SetFaction command does. `Player:set_faction` itself does not
-- ask. Allows everyone by default; override it in the faction definition.
-- ```
-- function FACTION:can_transfer(target, old_faction)
--   if target:get_gender() == 'no_gender' then
--     return false, 'error.faction.humans_only'
--   end
-- end
-- ```
-- @param target [Player the player who is to be moved into the faction]
-- @param old_faction [Faction the faction the player is in, nil if it is not registered]
-- @return [Boolean return false to refuse the transfer, optionally followed by a String
--   language phrase that tells why and a Map of its arguments]
function Faction:can_transfer(target, old_faction)
end

--- Registers the faction under its faction ID.
-- @see [Factions.add_faction]
function Faction:register()
  Factions.add_faction(self.faction_id, self)
end
