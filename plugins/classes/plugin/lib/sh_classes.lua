--- Player extensions of the Classes plugin: the class a player holds within their faction.
-- The class of a player belongs to their active character, where its ID is stored in the
-- `char_class` column. The player methods read the class on the server and the client and
-- check whether the player may switch to another one; on the server they also change it.
--
-- This file also holds the `Classes` functions that register and look up classes, count
-- their members against their limits, and the loader of class definition files.
-- @module [Player]

if !Classes then
  PLUGIN:set_global 'Classes'
end

local stored = Classes.stored or {}
Classes.stored = stored

--- Registers a class: normalizes its ID and the ID of its faction and fills in the defaults
-- of the missing fields. The faction does not have to be registered yet. Raises an error when
-- the class has no faction.
-- ```
-- local medic = CharacterClass.new('medic')
-- medic.name = 'Medic'
-- medic.faction = 'citizen'
-- medic.wage = 25
--
-- -- Same as medic:register()
-- Classes.add_class(medic.class_id, medic)
-- ```
-- @param id [String class ID, normalized with to_id]
-- @param data [CharacterClass the class to register; receives class_id]
-- @see [CharacterClass#register]
function Classes.add_class(id, data)
  if !isstring(id) or !istable(data) then return end

  if !isstring(data.faction) then
    error_with_traceback('Attempt to register the \''..id..'\' class without a faction!')

    return
  end

  data.class_id = id:to_id()
  data.faction = data.faction:to_id()
  data.name = data.name or 'Unknown Class'
  data.description = data.description or 'This class has no description set!'
  data.limit = tonumber(data.limit) or 0
  data.wage = tonumber(data.wage) or 0
  data.priority = tonumber(data.priority) or 0
  data.loadout = istable(data.loadout) and data.loadout or {}

  if data.selectable == nil then
    data.selectable = true
  end

  stored[data.class_id] = data
end

--- Returns the class registered under the exact ID.
-- @param id [String class ID]
-- @return [CharacterClass the class, or nil if it is not registered]
function Classes.find_by_id(id)
  return stored[id]
end

--- Finds a class by its ID or name, ignoring letter case.
-- @param name [String class ID or name, or a part of either]
-- @param strict=false [Boolean require the whole ID or name to match]
-- @return [CharacterClass/Boolean the first matching class, or false if nothing matched]
function Classes.find(name, strict)
  if !isstring(name) then return false end

  name = name:utf8lower()

  for k, v in pairs(stored) do
    local class_name = v.name:utf8lower()

    if strict then
      if k == name or class_name == name then
        return v
      end
    elseif k:find(name, 1, true) or class_name:find(name, 1, true) then
      return v
    end
  end

  return false
end

--- Returns every registered class.
-- @return [Map classes keyed by class ID]
function Classes.all()
  return stored
end

--- Returns the classes of a faction, ordered by ascending priority and then by class ID.
-- @param faction_id [String faction ID]
-- @return [List<CharacterClass> empty when the faction has no classes]
function Classes.get_faction_classes(faction_id)
  local classes = {}

  for k, v in pairs(stored) do
    if v.faction == faction_id then
      table.insert(classes, v)
    end
  end

  table.sort(classes, function(a, b)
    if a.priority != b.priority then
      return a.priority < b.priority
    end

    return a.class_id < b.class_id
  end)

  return classes
end

--- Returns the default class of a faction: the class that the default_class field of the
-- faction names, provided that it is registered and belongs to that faction.
-- @param faction_id [String faction ID]
-- @return [CharacterClass the default class, or nil if the faction has none]
function Classes.get_default(faction_id)
  local faction_table = isstring(faction_id) and Factions.find_by_id(faction_id)

  if !faction_table or !isstring(faction_table.default_class) then return end

  local class_table = stored[faction_table.default_class:to_id()]

  if class_table and class_table.faction == faction_table.faction_id then
    return class_table
  end
end

--- Returns the class of a character record: the class stored in its char_class field when it
-- is registered and belongs to the faction of the character, otherwise the default class of
-- that faction. Meant for the server, where character records have these fields.
-- @param char [Character the character record, or the character table of a bot]
-- @return [CharacterClass the class, or nil if the character has no class]
function Classes.get_character_class(char)
  if !istable(char) then return end

  local class_table = isstring(char.char_class) and stored[char.char_class]

  if class_table and class_table.faction == char.faction then
    return class_table
  end

  return Classes.get_default(char.faction)
end

--- Returns every connected player whose class is the given one.
-- @param id [String class ID]
-- @return [List<Player>]
function Classes.get_players(id)
  local players = {}

  for k, v in player.Iterator() do
    if v:get_class_id() == id then
      table.insert(players, v)
    end
  end

  return players
end

--- Returns how many players may hold a class at once.
-- @param id [String class ID]
-- @return [Number the limit; 0 when the class has no limit or is not registered]
function Classes.get_limit(id)
  local class_table = stored[id]

  if !class_table then return 0 end

  local limit = class_table.limit

  --- Lets plugins change how many players may hold a class at once, for example to scale
  -- the limit with the amount of players online. Called on both realms by
  -- `Classes.get_limit`, which the class menu and `Player:can_join_class` use.
  -- @param class_table [CharacterClass the class]
  -- @param limit [Number the limit set by the class definition, 0 for no limit]
  -- @return [Number the limit to use instead, 0 for no limit; return nothing to keep the
  --   limit of the class definition]
  local override = hook.Run('GetClassLimit', class_table, limit)

  if isnumber(override) then
    limit = override
  end

  return math.max(0, limit)
end

--- Checks whether a class has as many members as its limit allows.
-- @param id [String class ID]
-- @return [Boolean false as well when the class has no limit or is not registered]
function Classes.is_full(id)
  local limit = Classes.get_limit(id)

  return limit > 0 and #Classes.get_players(id) >= limit
end

--- Includes every file of a folder as a class definition. Each file gets a fresh CLASS global,
-- a CharacterClass named after the file, that is registered once the file has run.
-- ```
-- -- classes/sh_officer.lua, registered as 'officer'
-- CLASS.name = 'Officer'
-- CLASS.description = 'Leads a patrol team.'
-- CLASS.faction = 'police'
-- CLASS.color = Color(60, 100, 200)
-- CLASS.model = 'models/police.mdl'
-- CLASS.limit = 4
-- CLASS.wage = 40
-- CLASS.loadout = { 'weapon_stunstick', 'weapon_pistol' }
-- CLASS.selectable = false
-- CLASS.priority = 2
-- ```
-- @param directory [String folder to include files from]
function Classes.include_classes(directory)
  return Pipeline.include_folder('character_class', directory)
end

do
  local player_meta = FindMetaTable('Player')

  --- Returns the class the player holds. On the server it is read from the active character,
  -- so that it is right as soon as the character is selected; on the client it is the
  -- networked class.
  -- @return [CharacterClass the class, or nil if the player has no character or no class]
  function player_meta:get_class()
    if SERVER then
      if !self:is_character_loaded() then return end

      return Classes.get_character_class(self:get_character())
    end

    return stored[self:get_nv('char_class', '')]
  end

  --- Returns the ID of the class the player holds.
  -- @return [String class ID, or nil if the player has no character or no class]
  function player_meta:get_class_id()
    local class_table = self:get_class()

    return class_table and class_table.class_id
  end

  --- Checks whether the player holds the given class.
  -- @param id [String class ID]
  -- @return [Boolean]
  function player_meta:is_class(id)
    return id != nil and self:get_class_id() == id
  end

  --- Returns the wage of the class the player holds, before the AdjustPlayerWage hook.
  -- @return [Number 0 when the player has no class]
  function player_meta:get_wage()
    local class_table = self:get_class()

    return class_table and class_table.wage or 0
  end

  --- Returns the time at which the player may switch their class again.
  -- @return [Number a CurTime timestamp, 0 if the player has not switched their class yet]
  function player_meta:get_next_class_change()
    return self:get_nv('next_class_change', 0)
  end

  --- Checks whether the player may switch to a class by themselves: the class has to belong
  -- to their faction, be selectable and not full, the player must not hold it already or be
  -- on the class change cooldown, and the PlayerCanChangeClass hook must not refuse it. The
  -- class menu uses this on the client and `Player:join_class` on the server.
  -- ```
  -- local allowed, err, err_args = actor:can_join_class('officer')
  --
  -- if !allowed then
  --   actor:notify(err, err_args)
  -- end
  -- ```
  -- @param id [String class ID]
  -- @return [Boolean whether the switch is allowed, String error phrase when it is not, Map
  --   arguments of the error phrase if it has any]
  function player_meta:can_join_class(id)
    local class_table = isstring(id) and stored[id]

    if !class_table then
      return false, 'error.class.invalid', { class = tostring(id) }
    end

    if !self:is_character_loaded() or class_table.faction != self:get_faction_id() then
      return false, 'error.class.wrong_faction', { class = class_table.name }
    end

    local old_class = self:get_class()

    if old_class == class_table then
      return false, 'error.class.already'
    end

    if !class_table.selectable then
      return false, 'error.class.not_selectable'
    end

    local time_left = self:get_next_class_change() - CurTime()

    if time_left > 0 then
      return false, 'error.class.cooldown', { time = Flux.Lang:duration(math.ceil(time_left)) }
    end

    if Classes.is_full(id) and
       --- Decides whether a player may join a class that already has as many members as
       -- its limit allows. Called on both realms by `Player:can_join_class`, only for a
       -- class that is full.
       -- @param target [Player the player who wants to join the class]
       -- @param class_table [CharacterClass the class that is full]
       -- @return [Boolean return true to let the player in regardless of the limit]
       hook.Run('PlayerCanBypassClassLimit', self, class_table) != true then
      return false, 'error.class.full'
    end

    --- Decides whether a player may switch to a class by themselves. Called on both realms
    -- by `Player:can_join_class` after the checks of the plugin have passed: on the client
    -- for the class menu, and on the server before the class is changed. It is not called
    -- when the class is set with `Player:set_class`, as the SetClass command does.
    -- @param target [Player the player who wants to switch]
    -- @param class_table [CharacterClass the class they want to switch to]
    -- @param old_class [CharacterClass the class they hold now, nil if they have none]
    -- @return [Boolean return false to refuse the switch, String error phrase for the
    --   player, Map arguments of the error phrase]
    local allowed, err, err_args = hook.Run('PlayerCanChangeClass', self, class_table, old_class)

    if allowed == false then
      return false, err or 'error.class.not_allowed', err_args
    end

    return true
  end

  if SERVER then
    --- Sets the model of a player unless they have that model already.
    -- @param target [Player]
    -- @param model [String model path; ignored when it is not a string or is empty]
    local function set_model(target, model)
      if !isstring(model) or model == '' then return end

      if string.lower(target:GetModel() or '') != string.lower(model) then
        target:SetModel(model)
      end
    end

    --- Stores and networks the class of a player and, if it differs from the class they held,
    -- updates their model, swaps the weapons that `Classes.give_loadout` gave them for the
    -- loadout of the new class if they are alive, runs the callbacks of both classes and the
    -- OnPlayerClassChanged hook.
    -- @param target [Player a player with an active character]
    -- @param class_table [CharacterClass the new class, nil to leave the player without one]
    -- @param old_class [CharacterClass the class the player held, nil if they had none]
    local function change_class(target, class_table, old_class)
      target:set_character_var('char_class', class_table and class_table.class_id or '')

      if class_table == old_class then return end

      local model = class_table and class_table:get_model(target)

      if model then
        set_model(target, model)
      elseif old_class and old_class:get_model(target) then
        set_model(target, target:get_nv('model'))
      end

      if target:Alive() then
        local given = target.class_weapons

        if given then
          for k, v in pairs(given) do
            if !class_table or !table.HasValue(class_table.loadout, k) then
              target:StripWeapon(k)

              given[k] = nil
            end
          end
        end

        if class_table then
          Classes.give_loadout(target, class_table)
        end
      end

      if old_class then
        old_class:on_player_leave(target, class_table)
      end

      if class_table then
        class_table:on_player_join(target, old_class)
      end

      --- Called on the server after the class of a player has changed, through
      -- `Player:set_class`, `Player:join_class` or a change of their faction: the class has
      -- been stored on their character and networked, their model and weapons have been
      -- updated, and the on_player_leave and on_player_join callbacks of the classes have
      -- run. It is not called when a character is loaded.
      -- @param target [Player]
      -- @param class_table [CharacterClass the class the player holds now, nil if they were
      --   left without a class]
      -- @param old_class [CharacterClass the class the player held before, nil if they had
      --   none]
      hook.Run('OnPlayerClassChanged', target, class_table, old_class)
    end

    --- Gives a player the weapons of a class that they do not have yet, and remembers which
    -- ones it gave in the class_weapons field of the player: only those are taken away when
    -- the player changes class, so a weapon they hold for another reason, such as the default
    -- loadout or an equipped item, is left alone. Server only.
    -- @param target [Player]
    -- @param class_table=nil [CharacterClass the class whose loadout is given; the class of
    --   the player by default]
    function Classes.give_loadout(target, class_table)
      class_table = class_table or target:get_class()

      if !class_table then return end

      local given = target.class_weapons or {}

      target.class_weapons = given

      for k, v in ipairs(class_table.loadout) do
        if !target:HasWeapon(v) then
          target:Give(v)

          given[v] = true
        end
      end
    end

    --- Gives a player the model of their class, if the class has one. The model of the
    -- character is left as it is, and comes back once the player holds a class without a
    -- model. Server only.
    -- @param target [Player]
    function Classes.apply_model(target)
      local class_table = target:get_class()

      if class_table then
        set_model(target, class_table:get_model(target))
      end
    end

    --- Puts the player into a class of their faction regardless of its limit, of whether it
    -- is selectable and of the class change cooldown: stores the class on their character,
    -- networks it, applies its model and swaps the weapons of the old class for those of the
    -- new one if the player is alive. Server only.
    -- ```
    -- local success, err = target:set_class('officer')
    --
    -- if !success then
    --   actor:notify(err, { class = 'officer' })
    -- end
    -- ```
    -- @param id [String ID of a registered class of the player's faction]
    -- @return [Boolean whether the class was set, String error phrase when it was not; the
    --   phrases take the class as their {class} argument]
    function player_meta:set_class(id)
      local class_table = isstring(id) and stored[id]

      if !class_table then
        return false, 'error.class.invalid'
      end

      if !self:is_character_loaded() then
        return false, 'error.class.wrong_faction'
      end

      local char = self:get_character()

      if class_table.faction != char.faction then
        return false, 'error.class.wrong_faction'
      end

      change_class(self, class_table, Classes.get_character_class(char))

      return true
    end

    --- Puts the player into the default class of their faction, or leaves them without a
    -- class when the faction has none. The plugin calls it when the faction of a player
    -- changes. Server only.
    -- @param old_class=nil [CharacterClass the class to treat as the one the player held; by
    --   default the class stored on their character, whichever faction it belongs to]
    function player_meta:reset_class(old_class)
      if !self:is_character_loaded() then return end

      local char = self:get_character()

      if !old_class then
        old_class = isstring(char.char_class) and stored[char.char_class] or nil
      end

      change_class(self, Classes.get_default(char.faction), old_class)
    end

    --- Switches the player to a class the way the class menu does: only if
    -- `Player:can_join_class` allows it, and starting the cooldown of the
    -- class_change_cooldown config afterward. Server only.
    -- @param id [String class ID]
    -- @return [Boolean whether the player has switched, String error phrase when they have
    --   not, Map arguments of the error phrase if it has any]
    function player_meta:join_class(id)
      local allowed, err, err_args = self:can_join_class(id)

      if !allowed then
        return false, err, err_args
      end

      local success, set_err = self:set_class(id)

      if !success then
        return false, set_err, { class = tostring(id) }
      end

      local cooldown = tonumber(Config.get('class_change_cooldown')) or 0

      if cooldown > 0 then
        self:set_nv('next_class_change', CurTime() + cooldown, self)
      end

      return true
    end
  end
end

Pipeline.register('character_class', function(id, file_name, pipe)
  CLASS = CharacterClass.new(id)

  require_relative(file_name)

  CLASS:register() CLASS = nil
end)
