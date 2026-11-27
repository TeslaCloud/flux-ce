--- A faction: what characters are recognized as, an organization. It holds the name,
-- description, color and image of the faction, the species its members are, its ranks from the
-- lowest to the highest, its starter kit and the name its members are shown under. Members get
-- weapons, maximum health and armor from it when they spawn, stat bonuses (read by the Stats
-- plugin) and the feelings of the NPCs of the map. A rank can carry a model, weapons, maximum
-- health and armor of its own, the right to promote and demote other members, and the mark of
-- the rank that new members start with.
--
-- Nobody is put into a faction: a player is a member because of what they carry or wear, an
-- item whose definition sets `ITEM.faction` to the ID of the faction (see
-- `Factions.resolve_membership`), or because it is the `default_faction` of their species.
-- The `kit` of a faction lists the items that make someone a member.
--
-- Factions are normally defined in the files of a factions folder, where the object is
-- available as FACTION (see `Factions.include_factions`), and are registered with
-- `Faction:register`. A definition can override `Faction:get_display_name`,
-- `Faction:on_player_join`, `Faction:on_player_leave`, `Faction:on_character_create` and
-- `Faction:can_transfer`.

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

--- Creates a faction with default settings: the 'faction.unknown.*' phrases as its name and
-- description, the human species, priority 0, no ranks, no kit, no loadout, no name template
-- and no whitelist. Fields are left unset when no ID is given.
-- ```
-- local faction = Faction.new('police')
-- faction.name = 'Police'
-- faction.color = Color(60, 100, 200)
-- faction.whitelisted = true
-- faction.kit = { 'police_uniform' }
-- faction:add_rank('officer', 'Ofc.')
-- faction:register()
-- ```
--
-- The other fields are all optional:
-- ```
-- -- The species of the members: an item never makes a character of another species a member.
-- FACTION.species = 'human'
-- -- When a player carries the items of several factions, the highest priority wins; ties go
-- -- to the faction registered first.
-- FACTION.priority = 10
-- -- The name members are shown under, with {name} and {rank} (the name filter of the rank).
-- FACTION.name_template = '{rank} {name}'
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
  self.name = 'faction.unknown.title'
  self.description = 'faction.unknown.description'
  self.whitelisted = false
  self.color = Color(255, 255, 255)
  self.material = nil
  self.species = 'human'
  self.priority = 0
  self.kit = {}
  self.rank = {}
  self.name_template = nil
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

--- Returns the description of the faction.
-- @return [String]
function Faction:get_description()
  return self.description
end

--- Returns the species of the members of the faction.
-- @return [Species the species, nil when it is not registered]
function Faction:get_species()
  return Species.find_by_id(self.species)
end

--- Returns the item IDs of the starter kit of the faction: the items that make someone a
-- member, given to a character created with the faction as its starting option and by the
-- SetFaction command.
-- @return [List<String> item IDs, empty when the faction has no kit]
function Faction:get_kit()
  return istable(self.kit) and self.kit or {}
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

  for index, rank_table in ipairs(self.rank) do
    if rank_table.id:utf8lower() == lowered then
      return index, rank_table
    end
  end
end

--- Returns the rank that new members of the faction start with: the first rank that was
-- added with the default field set, or else the lowest rank.
-- @return [Number rank index; 1 as well when the faction has no ranks]
function Faction:get_default_rank()
  for index, rank_table in ipairs(self.rank) do
    if rank_table.default then
      return index
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
    for _, weapon_class in ipairs(self.loadout) do
      if !table.HasValue(loadout, weapon_class) then
        table.insert(loadout, weapon_class)
      end
    end
  end

  if rank_table and istable(rank_table.loadout) then
    for _, weapon_class in ipairs(rank_table.loadout) do
      if !table.HasValue(loadout, weapon_class) then
        table.insert(loadout, weapon_class)
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

--- Adds a rank above the ranks added so far. Besides its ID and the text it puts into
-- display names, a rank can carry optional fields:
-- * `model`: model that holders of the rank use instead of the model of their character,
--   either a path or a table of paths keyed by 'male', 'female', 'no_gender' and 'universal'.
-- * `model_class`: animation class of that model (see `Flux.Anim:set_model_class`). A single
--   path gets no class without it; each path of a table of models defaults to the model class
--   the species of the faction has for the same key.
-- * `loadout`: List<String> of weapon classes given on spawn on top of those of the faction.
-- * `max_health`, `max_armor`: replace the maximum health and armor of the faction.
-- * `default`: true makes it the rank that new members of the faction start with.
-- * `can_promote`: the highest rank a holder may promote other members to, as a rank index
--   or a rank ID; true stands for the rank right below their own.
-- * `can_demote`: the highest rank a holder may demote other members from, in the same form.
-- ```
-- FACTION:add_rank('recruit', 'Rct.', { default = true })
-- FACTION:add_rank('officer', 'Ofc.', { loadout = { 'weapon_pistol' }, max_armor = 50 })
-- FACTION:add_rank('sergeant', 'Sgt.', {
--   model = 'models/police_sergeant.mdl',
--   can_promote = 'officer',
--   can_demote = 'officer'
-- })
-- ```
-- @param id [String rank ID; nothing is added when it is nil]
-- @param name_filter=id [String/Map text that replaces {rank} in display names. A table
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

--- Returns the name a member of the faction is shown under in place of the real name of their
-- character, or nothing to show the real name. By default the name_template of the faction is
-- filled in, its {name} with the real name and its {rank} with the name filter of the rank of
-- the member, in one pass (see `string.fmt`); {rank} is empty for a member without a rank.
-- The result is brought to the form of `Characters.normalize_name`, so the spaces around an
-- empty placeholder disappear. A definition overrides it to build the name in any other way.
-- Called on the server whenever the membership, the rank or the items of a member change (see
-- `Characters.refresh_display_name`).
-- ```
-- FACTION.name_template = '{rank} {name}'
-- FACTION:add_rank('officer', 'Ofc.')
--
-- faction_table:get_display_name(target, 'John Doe', faction_table:get_rank(1)) -- 'Ofc. John Doe'
-- ```
-- @param _target [Player the member]
-- @param name [String the real name of the character]
-- @param rank_table [Map the rank of the member, nil when they have none]
-- @return [String the name to show, nil for the real name]
function Faction:get_display_name(_target, name, rank_table)
  local template = self.name_template

  if !isstring(template) or template == '' then return end

  local rank_name = rank_table and isstring(rank_table.name) and rank_table.name or ''

  local display_name = string.fmt(template, { name = name, rank = rank_name })

  return Characters.normalize_name(display_name)
end

--- Called on the server when a player becomes a member of this faction, as their membership is
-- resolved again (see `Factions.refresh_membership`): when what they carry or wear changes
-- their faction to this one, and on the first resolution after any character of this
-- faction has been applied, which starts from no faction. The networked faction, rank and
-- team of the player are those of this faction already. Does nothing by default; override
-- it in the faction definition.
-- @param _target [Player]
function Faction:on_player_join(_target)
end

--- Called on the server when a player stops being a member of this faction: when their
-- membership is resolved again and what they carry or wear puts them into another faction
-- or none, and when their membership is forgotten: before another character is applied
-- (which is the active character of the player by then), when the active character is
-- dropped and when the player disconnects. The networked
-- faction, rank and team of the player are those of the faction they are in afterwards, or
-- cleared. Does nothing by default; override it in the faction definition.
-- @param _target [Player]
function Faction:on_player_leave(_target)
end

--- Called on the server when a character that starts as a member of this faction is about to
-- be created, after the creation data has passed the checks of the Characters plugin. The
-- callback may change the data in place, for instance to set the rank the character starts
-- with, and may refuse the character. Does nothing by default; override it in the faction
-- definition.
-- ```
-- function FACTION:on_character_create(owner, data)
--   if #Factions.get_players(self.faction_id) == 0 then
--     data.rank = self:find_rank('sergeant')
--   end
-- end
-- ```
-- @param _owner [Player the player the character is created for]
-- @param _data [Map creation data: name, phys_desc, species, gender (a CHAR_GENDER_* value),
--   model, skin and faction; rank may be set]
-- @return [Boolean/Number return false to refuse the character, optionally followed by a
--   String language phrase that tells the player why and a Map of its arguments; or return
--   a CHAR_ERR_* code to refuse it with the text of that code]
function Faction:on_character_create(_owner, _data)
end

--- Called on the server when `Factions.can_transfer` checks whether a player may be given the
-- starter kit of this faction, as the SetFaction command does. Allows everyone by default;
-- override it in the faction definition.
-- ```
-- function FACTION:can_transfer(target, old_faction)
--   if target:get_gender() == 'female' then
--     return false, 'error.faction.men_only'
--   end
-- end
-- ```
-- @param _target [Player the player who is to be given the kit]
-- @param _old_faction [Faction the faction the player is in, nil when they are in none]
-- @return [Boolean return false to refuse the transfer, optionally followed by a String
--   language phrase that tells why and a Map of its arguments]
function Faction:can_transfer(_target, _old_faction)
end

--- Registers the faction under its faction ID.
-- @see [Factions.add_faction]
function Faction:register()
  Factions.add_faction(self.faction_id, self)
end
