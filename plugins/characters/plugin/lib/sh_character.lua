--- Player extensions of the Characters plugin: the characters of a player and the active one.
-- A player owns a list of characters and has at most one active character at a time. The
-- player methods return these characters (`Player:get_all_characters`, `Player:get_character`)
-- and the fields of the active one; on the server they are `Character` records, on the client
-- the networked tables that the server sends to the owner of the characters. Server-side
-- methods select the active character, set its fields and save it.
--
-- This file also holds the `Characters` functions that create, save, delete, ban and edit
-- characters, and the network handlers behind the character menus. A request of a player to
-- load or delete a character is checked first: `Characters.can_use` and
-- `Characters.can_delete` apply the rules of the plugin and run the `PlayerCanUseCharacter`,
-- `PlayerCanSwitchCharacter` and `PlayerCanDeleteCharacter` hooks, and a refused request is
-- answered with a reason that the menu shows.
--
-- Every character also has generic data: a table of values kept under string keys, saved with
-- the character in its `data` column and read and written with `Player:get_character_data`
-- and `Player:set_character_data` (or `Character:get_data` and `Character:set_data`). The
-- data stays on the server unless a key is passed to `Characters.network_data`, which makes
-- the server send the value of that key to the owner of the character, and to nobody else.
-- @module [Player]

local IsValid = IsValid
local isnumber = isnumber
local isstring = isstring
local istable = istable
local tobool = tobool
local tonumber = tonumber
local cable_send = Cable.send
local config_get = Config.get
local string_trim = string.Trim

if !Characters then
  PLUGIN:set_global('Characters')
end

Characters.networked_data = Characters.networked_data or {}

CHAR_GENDER_MALE = 0
CHAR_GENDER_FEMALE = 1
CHAR_GENDER_NONE = 2

local translate_gender = {
  [CHAR_GENDER_MALE] = 'male',
  [CHAR_GENDER_FEMALE] = 'female',
  [CHAR_GENDER_NONE] = 'no_gender'
}

--- Makes the server send a key of the generic character data to the owner of the character.
-- Without it the data never leaves the server. Once a key is registered, its value is part of
-- the character list that the owner receives and is sent again whenever it is set, so the
-- owner can read it with `Player:get_character_data`; other players never receive it. Call
-- it while the plugin that owns the key loads. It only has an effect on the server, but may
-- be called on both realms.
-- ```
-- Characters.network_data('flags')
-- ```
-- @param key [String key of the character data]
function Characters.network_data(key)
  if !isstring(key) then return end

  Characters.networked_data[key] = true
end

--- Checks whether a key of the generic character data is sent to the owner of the character.
-- @param key [String key of the character data]
-- @return [Boolean]
function Characters.is_data_networked(key)
  return Characters.networked_data[key] == true
end

--- Returns a value from the generic data of a character.
-- On the client only the keys registered with `Characters.network_data` are known, and only
-- for the characters of the local player.
-- @param character [Character/Map character record, or networked character data on the client]
-- @param key [String]
-- @param default=nil [Any value to return when nothing is stored under the key]
-- @return [Any]
function Characters.get_custom_data(character, key, default)
  local custom_data = istable(character) and character.custom_data

  if istable(custom_data) and custom_data[key] != nil then
    return custom_data[key]
  end

  return default
end

--- Returns how many characters a player may have: the `character_limit` config, unless a
-- GetCharacterLimit hook returns another number.
-- @param target [Player]
-- @return [Number]
function Characters.get_limit(target)
  local limit = config_get('character_limit', 5)
  --- Lets plugins change how many characters a player may have. Called on the server when a
  -- character is about to be created, and on the client for the local player when the main
  -- menu decides whether the creation screen may be opened, so a handler that is meant to be
  -- seen in the menu has to be shared.
  -- @param target [Player the player whose limit is requested]
  -- @param limit [Number the value of the character_limit config]
  -- @return [Number the limit to use for this player; return nothing to keep the config value]
  local adjusted = hook.Run('GetCharacterLimit', target, limit)

  if isnumber(adjusted) then
    return adjusted
  end

  return limit
end

--- Checks whether a player has as many characters as they may have.
-- On the server the player must have their database record, on the client only the local
-- player can be checked.
-- @param target [Player]
-- @return [Boolean true when the player cannot create another character]
-- @see [Characters.get_limit]
function Characters.limit_reached(target)
  return #target:get_all_characters() >= Characters.get_limit(target)
end

--- Creates a character for a player unless a PlayerCreateCharacter hook rejects the data.
-- On the server the character is then saved and sent to its owner.
-- ```
-- local status = Characters.create(target, {
--   name = 'John Doe',
--   phys_desc = 'A tall man in a worn coat.',
--   gender = CHAR_GENDER_MALE,
--   model = 'models/humans/group01/male_02.mdl',
--   skin = 0
-- })
--
-- if status != CHAR_SUCCESS then
--   -- status is one of the CHAR_ERR_* codes
-- end
-- ```
-- @param target [Player owner of the new character]
-- @param data [Map creation data: name, phys_desc, gender, model and optionally skin. Set
--   name_generated to true when the name was not chosen by the player, which lets it
--   repeat the name of another character, and description_generated to true when the
--   description was not written by the player, which frees it from the length limits]
-- @return [Number CHAR_SUCCESS, or the CHAR_ERR_* code returned by the hook]
function Characters.create(target, data)
  --- Validates the data of a character that is about to be created. Called by
  -- `Characters.create`, which the plugin runs on the server, before the character record is
  -- built.
  -- @param owner [Player the player the character is created for]
  -- @param data [Map creation data: name, phys_desc, gender, model, skin, name_generated,
  --   description_generated and the fields that other plugins add]
  -- @return [Number return a CHAR_ERR_* code to refuse the character; it becomes the result of
  --   Characters.create and is sent to the client. Return nothing to accept the data]
  local hook_result = hook.Run('PlayerCreateCharacter', target, data)

  if hook_result then
    return hook_result
  end

  local char = Character.new()
    char.steam_id = target:SteamID()
    char.name = data.name
    char.model = data.model or ''
    char.skin = data.skin or 0
    char.gender = data.gender
    char.phys_desc = data.phys_desc or ''
    char.health = 100
    char.banned = false
    char.user = target.record
  table.insert(target.record.characters, char)

  if SERVER then
    --- Called on the server when a character has been built and added to the record of its
    -- owner, before it is saved and sent to the owner. Handlers copy their own fields from the
    -- creation data to the character.
    -- @param owner [Player]
    -- @param char [Character the new character, not saved yet]
    -- @param char_data [Map creation data the character was built from]
    hook.Run('PostCreateCharacter', target, char, data)

    Characters.remember_name(char.name)
    Characters.save(target, char)

    cable_send(target, 'fl_create_character', Characters.to_networkable(target, char))
  end

  return CHAR_SUCCESS
end

if SERVER then
  Characters.taken_names = Characters.taken_names or {}

  local request_delay = 1

  --- Brings a character name to the form in which names are compared: lower case, without
  -- surrounding whitespace and with every run of whitespace turned into a single space.
  -- @param name [String]
  -- @return [String]
  local function normalize_name(name)
    return (string_trim(name):gsub('%s+', ' ')):utf8lower()
  end

  --- Checks whether the player has sent a character request less than a second ago, and
  -- starts the wait for the next one when they have not.
  -- @param actor [Player]
  -- @return [Boolean true when the request has to be refused]
  local function is_throttled(actor)
    local cur_time = CurTime()

    if actor.next_character_request and actor.next_character_request > cur_time then
      return true
    end

    actor.next_character_request = cur_time + request_delay

    return false
  end

  --- Tells a player that their request to load or delete a character was refused.
  -- @param actor [Player]
  -- @param action [String 'select' or 'delete']
  -- @param reason [String text or language phrase]
  -- @param arguments=nil [Map values to substitute into the phrase]
  local function refuse_request(actor, action, reason, arguments)
    cable_send(actor, 'fl_character_request_failed', action, reason, arguments)
  end

  --- Returns the part of the generic data of a character that its owner receives: the keys
  -- registered with `Characters.network_data`.
  -- @param character [Character]
  -- @return [Map]
  local function get_networked_data(character)
    local networked = {}
    local custom_data = character.custom_data

    if istable(custom_data) then
      local networked_keys = Characters.networked_data

      for key, value in pairs(custom_data) do
        if networked_keys[key] == true then
          networked[key] = value
        end
      end
    end

    return networked
  end

  --- Returns the player a character belongs to, if they are on the server. Server only.
  -- @param character [Character]
  -- @return [Player the owner, or nil when they are not connected]
  function Characters.get_owner(character)
    local user = istable(character) and character.user
    local owner = istable(user) and user.player

    if IsValid(owner) then
      return owner
    end
  end

  --- Sets a value in the generic data of a character. The value is written to the database
  -- the next time the character is saved; values must be serializable, so no functions. If
  -- the key is registered with `Characters.network_data` and the owner of the character is
  -- connected, the new value is sent to them. A table that is changed in place has to be set
  -- again to be sent. Server only.
  -- ```
  -- Characters.set_custom_data(character, 'spawn_position', target:GetPos())
  -- ```
  -- @param character [Character]
  -- @param key [String nothing happens when it is not a string]
  -- @param value [Any nil removes the key]
  function Characters.set_custom_data(character, key, value)
    if !istable(character) or !isstring(key) then return end

    character.custom_data = character.custom_data or {}
    character.custom_data[key] = value

    if Characters.is_data_networked(key) and character.id then
      local owner = Characters.get_owner(character)

      if owner and !owner:IsBot() then
        cable_send(owner, 'fl_character_data', tonumber(character.id), key, value)
      end
    end
  end

  --- Records that a character bears a name, so that `Characters.is_name_taken` knows it.
  -- `Characters.create` and `Characters.set_name` call it themselves. Server only.
  -- @param name [String]
  function Characters.remember_name(name)
    if !isstring(name) then return end

    local key = normalize_name(name)

    Characters.taken_names[key] = (Characters.taken_names[key] or 0) + 1
  end

  --- Records that a character no longer bears a name. `Characters.delete` and
  -- `Characters.set_name` call it themselves. Server only.
  -- @param name [String]
  function Characters.forget_name(name)
    if !isstring(name) then return end

    local key = normalize_name(name)
    local count = (Characters.taken_names[key] or 0) - 1

    Characters.taken_names[key] = count > 0 and count or nil
  end

  --- Checks whether a character of any player, connected or not, already has a name. Names
  -- are compared without regard to letter case and surrounding or repeated whitespace. The
  -- names are read from the database when the server starts. Server only.
  -- @param name [String]
  -- @param except=nil [Character character whose own name does not count, for renaming it]
  -- @return [Boolean]
  function Characters.is_name_taken(name, except)
    if !isstring(name) then return false end

    local key = normalize_name(name)
    local count = Characters.taken_names[key] or 0

    if istable(except) and isstring(except.name) and normalize_name(except.name) == key then
      count = count - 1
    end

    return count > 0
  end

  --- Finds the characters that have a name, compared without regard to letter case. The
  -- characters of connected players are searched first; only when none of them matches are
  -- the characters of offline players loaded from the database, which makes the callback run
  -- later. Server only.
  -- @param name [String]
  -- @param callback [Function receives a List<Character>, empty when nothing was found]
  function Characters.find_by_name(name, callback)
    local key = normalize_name(name)
    local found = {}

    for k, v in player.Iterator() do
      local record = v.record

      if !v:IsBot() and istable(record) and istable(record.characters) then
        for k1, v1 in ipairs(record.characters) do
          if isstring(v1.name) and normalize_name(v1.name) == key then
            found[#found + 1] = v1
          end
        end
      end
    end

    if #found > 0 then
      return callback(found)
    end

    local answered = false

    Character:where('lower(name) = lower(?)', string_trim(name)):get(function(characters)
      if answered then return end

      answered = true

      callback(characters)
    end):rescue(function()
      if answered then return end

      answered = true

      callback({})
    end)
  end

  --- Checks whether a player may load one of their characters. A banned character and the
  -- character that is already active are always refused. A player who is switching away
  -- from a character that is not banned has to pass the PlayerCanSwitchCharacter hook, and
  -- every load the PlayerCanUseCharacter hook. Server only.
  -- @param actor [Player]
  -- @param character [Character the character to load; refused when nil]
  -- @return [Boolean true when the character may be loaded; otherwise false, String the
  --   reason as a language phrase and Map the arguments of the phrase]
  function Characters.can_use(actor, character)
    if !character then
      return false, 'error.character.invalid'
    end

    if tobool(character.banned) then
      return false, 'error.character.banned'
    end

    local current = actor:get_character()

    if current == character then
      return false, 'error.character.already_active'
    end

    if actor:is_character_loaded() and current and !tobool(current.banned) then
      --- Decides whether a player may leave their active character for another one. Called
      -- on the server when a player who has an active character that is not banned asks to
      -- load another character. The Characters plugin itself refuses while the player is
      -- dead or ragdolled.
      -- @param actor [Player the player who wants to switch]
      -- @param character [Character the character they want to load]
      -- @param current [Character their active character]
      -- @return [Boolean return false to refuse, String a language phrase that tells the
      --   player why and Map the arguments of the phrase; a generic text is shown when the
      --   reason is omitted]
      local allowed, reason, arguments = hook.Run('PlayerCanSwitchCharacter', actor, character, current)

      if allowed == false then
        return false, isstring(reason) and reason or 'error.character.cannot_switch', arguments
      end
    end

    --- Decides whether a player may load one of their characters. Called on the server for
    -- every request to load a character, after the plugin's own checks and, for a player who
    -- is switching characters, after the PlayerCanSwitchCharacter hook.
    -- @param actor [Player the player who wants to load the character]
    -- @param character [Character the character they want to load]
    -- @return [Boolean return false to refuse, String a language phrase that tells the player
    --   why and Map the arguments of the phrase; a generic text is shown when the reason is
    --   omitted]
    local allowed, reason, arguments = hook.Run('PlayerCanUseCharacter', actor, character)

    if allowed == false then
      return false, isstring(reason) and reason or 'error.character.cannot_use', arguments
    end

    return true
  end

  --- Checks whether a player may delete one of their characters. The active character and
  -- banned characters are always refused; anything else has to pass the
  -- PlayerCanDeleteCharacter hook. Server only.
  -- @param actor [Player]
  -- @param character [Character the character to delete; refused when nil]
  -- @return [Boolean true when the character may be deleted; otherwise false, String the
  --   reason as a language phrase and Map the arguments of the phrase]
  function Characters.can_delete(actor, character)
    if !character then
      return false, 'error.character.invalid'
    end

    if actor:get_character() == character then
      return false, 'error.character.delete_active'
    end

    if tobool(character.banned) then
      return false, 'error.character.delete_banned'
    end

    --- Decides whether a player may delete one of their characters. Called on the server
    -- for every request to delete a character that is neither active nor banned.
    -- @param actor [Player the player who wants to delete the character]
    -- @param character [Character the character they want to delete]
    -- @return [Boolean return false to refuse, String a language phrase that tells the player
    --   why and Map the arguments of the phrase; a generic text is shown when the reason is
    --   omitted]
    local allowed, reason, arguments = hook.Run('PlayerCanDeleteCharacter', actor, character)

    if allowed == false then
      return false, isstring(reason) and reason or 'error.character.cannot_delete', arguments
    end

    return true
  end

  --- Opens the main menu on the client of a player, or refreshes its buttons when it is
  -- already open, and optionally shows a message in it. Server only.
  -- @param target [Player]
  -- @param message=nil [String text or language phrase to show in the menu]
  -- @param arguments=nil [Map values to substitute into the phrase]
  function Characters.open_menu(target, message, arguments)
    if !IsValid(target) or target:IsBot() then return end

    cable_send(target, 'fl_character_menu', message, arguments)
  end

  --- Writes the health, armor and reserve ammo of a player into a character. A player who
  -- is dead leaves the character without saved health, armor and ammo, so that it is loaded
  -- with full health next time. Server only.
  -- @param owner [Player]
  -- @param character [Character]
  function Characters.store_vitals(owner, character)
    if owner:Alive() and owner:Health() > 0 then
      local ammo = {}

      for ammo_id, amount in pairs(owner:GetAmmo()) do
        local ammo_name = game.GetAmmoName(ammo_id)

        if ammo_name and amount > 0 then
          ammo[ammo_name] = amount
        end
      end

      character.health = owner:Health()
      character.armor = owner:Armor()
      character:set_ammo(ammo)
    else
      character.health = nil
      character.armor = nil
      character.ammo = nil
    end
  end

  --- Gives a player the health, armor and reserve ammo saved with a character. Without
  -- saved health the player keeps full health. Server only.
  -- @param owner [Player]
  -- @param character [Character]
  function Characters.restore_vitals(owner, character)
    local health = tonumber(character.health)

    owner:SetHealth(health and health > 0 and health or owner:GetMaxHealth())
    owner:SetArmor(tonumber(character.armor) or 0)
    owner:StripAmmo()

    for ammo_name, amount in pairs(character:get_ammo()) do
      if isstring(ammo_name) and isnumber(amount) and game.GetAmmoID(ammo_name) != -1 then
        owner:SetAmmo(amount, ammo_name)
      end
    end

    owner.vitals_restored = true
  end

  --- Bans or unbans a character and saves it. A banned character cannot be loaded or
  -- deleted by its owner and is marked as banned in their character list. If the character
  -- is the active one of a connected player, its health, armor and ammo are saved first,
  -- the player is killed silently and kept from respawning, and the main menu opens for
  -- them so that they can pick another character. Unbanning the active character of a
  -- connected player respawns them with what was saved. Runs the CharacterBanChanged hook.
  -- Server only.
  -- @param character [Character a record of a connected or an offline player]
  -- @param banned [Boolean]
  function Characters.set_banned(character, banned)
    if !istable(character) then return end

    banned = tobool(banned)

    local was_banned = tobool(character.banned)
    local owner = Characters.get_owner(character)
    local active = owner != nil and owner:get_character() == character

    if banned and !was_banned and active and owner.vitals_restored then
      Characters.store_vitals(owner, character)
    end

    character.banned = banned

    if owner then
      if active and was_banned and !banned and !owner:Alive() then
        owner:Spawn()

        Characters.restore_vitals(owner, character)
      end

      Characters.save(owner, character)
      Characters.send_to_client(owner)

      if active and banned then
        if owner:Alive() then
          owner:KillSilent()
        end

        Characters.open_menu(owner, 'notification.character_banned', { name = character.name })
      elseif active and was_banned then
        Characters.open_menu(owner)
      end
    elseif isfunction(character.save) then
      character:save()
    end

    --- Called on the server after a character has been banned or unbanned and saved.
    -- @param owner [Player the owner of the character, nil when they are not connected]
    -- @param character [Character]
    -- @param banned [Boolean true when the character is banned now]
    hook.Run('CharacterBanChanged', owner, character, banned)
  end

  --- Changes the physical description of a player's active character on their own request.
  -- The text is trimmed, its line breaks are replaced with ' | ', and it is refused when its
  -- length is outside of the `character_min_desc_len` and `character_max_desc_len` configs,
  -- when the player has no character or when they changed it less than a second ago. The
  -- player is notified of the outcome. Server only.
  -- @param actor [Player]
  -- @param text [String the new description]
  -- @return [Boolean true when the description was changed]
  function Characters.change_desc(actor, text)
    if !isstring(text) or !actor:is_character_loaded() then
      actor:notify('error.cant_now')

      return false
    end

    local cur_time = CurTime()

    if actor.next_desc_change and actor.next_desc_change > cur_time then
      actor:notify('error.wait')

      return false
    end

    local new_desc = string_trim(text):gsub('\n', ' | ')
    local length = utf8.len(new_desc)
    local min_length = config_get('character_min_desc_len')
    local max_length = config_get('character_max_desc_len')

    if !isnumber(length) or length < min_length or length > max_length then
      actor:notify('ui.char_create.desc_len', { min = min_length, max = max_length })

      return false
    end

    actor.next_desc_change = cur_time + request_delay

    Characters.set_desc(actor, new_desc)
    actor:notify('notification.desc_changed', { desc = new_desc })

    return true
  end

  --- Sends the networkable data of all of a player's characters to that player. Server only.
  -- @param target [Player]
  function Characters.send_to_client(target)
    cable_send(target, 'fl_characters_load', Characters.all_to_networkable(target))
  end

  --- Returns the networkable data of every character of a player. Server only.
  -- @param target [Player]
  -- @return [List<Map> one entry per character, empty when the player has no record]
  -- @see [Characters.to_networkable]
  function Characters.all_to_networkable(target)
    local characters = target.record and target.record.characters or {}
    local ret = {}

    for k, v in pairs(characters) do
      ret[k] = Characters.to_networkable(target, v)
    end

    return ret
  end

  --- Builds the table of character fields that is sent to the owning client: id, user_id,
  -- steam_id, name, gender, phys_desc, model, skin, banned and custom_data, which holds the
  -- keys of the generic data registered with `Characters.network_data`. Server only.
  -- @param target [Player owner of the character]
  -- @param char [Character]
  -- @return [Map character data, or nil if the player or the character is not valid]
  function Characters.to_networkable(target, char)
    if !IsValid(target) or !char then return end

    return {
      id = tonumber(char.id),
      user_id = char.user_id,
      steam_id = target:SteamID(),
      name = char.name,
      gender = char.gender,
      phys_desc = char.phys_desc or 'This character has no physical description set!',
      model = char.model or 'models/humans/group01/male_02.mdl',
      skin = char.skin or 1,
      banned = tobool(char.banned),
      custom_data = get_networked_data(char)
    }
  end

  --- Runs the SaveCharacterData hook and saves the player's record to the database, unless a
  -- PreSaveCharacter hook returns false. Server only.
  -- @param target [Player]
  -- @param character [Character]
  function Characters.save(target, character)
    if !IsValid(target) or !istable(character) or
       --- Lets plugins prepare for or prevent the saving of a character. Called on the
       -- server by `Characters.save`, before the SaveCharacterData hook.
       -- @param owner [Player]
       -- @param character [Character the character that is about to be saved]
       -- @return [Boolean return false to cancel the save]
       hook.Run('PreSaveCharacter', target, character) == false then return end

    --- Called on the server right before the record of a player is saved together with a
    -- character. Handlers write the data they keep for the character into its fields.
    -- @param owner [Player]
    -- @param character [Character the character that is being saved]
    hook.Run('SaveCharacterData', target, character)

    target:save_player()
  end

  --- Destroys one of the player's characters, removes it from their record, frees its name
  -- and resends the character list to the player. Nothing is checked here: the requests of
  -- players go through `Characters.can_delete` first. Server only.
  -- @param target [Player]
  -- @param id [Number character ID]
  function Characters.delete(target, id)
    local char = target:get_character_by_id(id)

    if char then
      char:destroy()

      Characters.forget_name(char.name)

      for k, v in pairs(target:get_all_characters()) do
        if tonumber(v.id) == id then
          table.remove(target.record.characters, k)

          break
        end
      end
    end

    Characters.send_to_client(target)
  end

  --- Changes the name of the player's active character, networks it and runs the
  -- CharacterNameChanged hook. The name is not checked against the names of other
  -- characters; use `Characters.is_name_taken` first where that matters. Server only.
  -- @param target [Player]
  -- @param new_name [String ignored when it is not a string]
  function Characters.set_name(target, new_name)
    if !new_name or !isstring(new_name) then return end

    local char = target:get_character()
    local old_name = target:get_nv('name')

    if char then
      if !target:IsBot() then
        Characters.forget_name(char.name)
        Characters.remember_name(new_name)
      end

      char.name = new_name or char.name
    end

    target:set_nv('name', new_name)
    --- Called on the server after `Characters.set_name` has changed the name of a player's
    -- active character and networked it.
    -- @param owner [Player]
    -- @param char [Character the active character, nil if the player has none]
    -- @param new_name [String]
    -- @param old_name [String the name that was networked before the change]
    hook.Run('CharacterNameChanged', target, char, new_name, old_name)

    Characters.send_to_client(target)
  end

  --- Changes the physical description of the player's active character, networks it and runs
  -- the CharacterDescChanged hook. Server only.
  -- @param target [Player]
  -- @param new_desc [String ignored when it is not a string]
  function Characters.set_desc(target, new_desc)
    if !new_desc or !isstring(new_desc) then return end

    local char = target:get_character()
    local old_desc = target:get_nv('phys_desc')

    if char then
      char.phys_desc = new_desc or char.phys_desc
    end

    target:set_nv('phys_desc', new_desc)
    --- Called on the server after `Characters.set_desc` has changed the physical description
    -- of a player's active character and networked it.
    -- @param owner [Player]
    -- @param char [Character the active character, nil if the player has none]
    -- @param new_desc [String]
    -- @param old_desc [String the description that was networked before the change]
    hook.Run('CharacterDescChanged', target, char, new_desc, old_desc)

    Characters.send_to_client(target)
  end

  --- Changes the model of the player and of their active character, networks it and runs the
  -- CharacterModelChanged hook. Server only.
  -- @param target [Player]
  -- @param model [String model path; ignored when it is not a string]
  function Characters.set_model(target, model)
    if !model or !isstring(model) then return end

    local char = target:get_character()
    local old_model = target:get_nv('model')

    if char then
      char.model = model or char.model
    end

    target:set_nv('model', model)
    target:SetModel(model)
    --- Called on the server after `Characters.set_model` has changed the model of a player and
    -- of their active character and networked it.
    -- @param owner [Player]
    -- @param char [Character the active character, nil if the player has none]
    -- @param model [String the new model path]
    -- @param old_model [String the model that was networked before the change]
    hook.Run('CharacterModelChanged', target, char, model, old_model)

    Characters.send_to_client(target)
  end

  --- Changes the gender of the player's active character, networks it and runs the
  -- CharacterGenderChanged hook. Server only.
  -- @param target [Player]
  -- @param new_gender [Number/String CHAR_GENDER_* value, or 'male', 'female' or 'no_gender']
  function Characters.set_gender(target, new_gender)
    new_gender = isstring(new_gender) and table.KeyFromValue(translate_gender, new_gender) or new_gender

    if !new_gender then return end

    local char = target:get_character()
    local old_gender = target:get_nv('gender')

    if char then
      char.gender = new_gender or char.gender
    end

    target:set_nv('gender', new_gender)
    --- Called on the server after `Characters.set_gender` has changed the gender of a player's
    -- active character and networked it.
    -- @param owner [Player]
    -- @param char [Character the active character, nil if the player has none]
    -- @param new_gender [Number CHAR_GENDER_* value]
    -- @param old_gender [Number the CHAR_GENDER_* value that was networked before the change]
    hook.Run('CharacterGenderChanged', target, char, new_gender, old_gender)

    Characters.send_to_client(target)
  end

  MVC.handler('fl_create_character', function(actor, data)
    if !istable(data) then
      respond_to { success = false, status = CHAR_ERR_UNKNOWN }

      return
    end

    local requested_name = data.name
    local requested_description = data.description

    --- Called on the server when the request of a client to create a character arrives, before
    -- the data is converted and passed to `Characters.create`. Handlers can fill in or change
    -- the data in place. A name that a handler has replaced counts as generated and may
    -- repeat the name of another character; a description that a handler has replaced
    -- counts as generated and may be of any length.
    -- @param actor [Player the player who sent the request]
    -- @param data [Map data collected by the creation menu: name, description, gender ('male',
    --   'female' or 'universal'), model, skin and the fields that other stages add]
    hook.Run('PreCreateCharacter', actor, data)

    data.name_generated = data.name != requested_name
    data.description_generated = data.description != requested_description
    data.gender = (data.gender == 'female' and CHAR_GENDER_FEMALE) or
      (data.gender == 'universal' and CHAR_GENDER_NONE) or CHAR_GENDER_MALE
    data.phys_desc = data.description

    local status = Characters.create(actor, data)

    Flux.dev_print('Creating character. Status: '..status)

    if status == CHAR_SUCCESS then
      Characters.send_to_client(actor)

      respond_to { success = true, status = status }

      Flux.dev_print('Success')
    else
      respond_to { success = false, status = status }

      Flux.dev_print('Error')
    end
  end)

  Cable.receive('fl_player_delete_character', function(actor, id)
    if !isnumber(id) or !istable(actor.record) then return end

    if is_throttled(actor) then
      refuse_request(actor, 'delete', 'error.wait')

      return
    end

    local character = actor:get_character_by_id(id)
    local allowed, reason, arguments = Characters.can_delete(actor, character)

    if !allowed then
      refuse_request(actor, 'delete', reason, arguments)

      return
    end

    Flux.dev_print(actor:name()..' has deleted character #'..id)

    --- Called on the server when a player has asked to delete one of their characters, right
    -- before it is deleted. The request has passed `Characters.can_delete` by then.
    -- @param actor [Player]
    -- @param id [Number ID of the character]
    -- @param character [Character the character that is about to be deleted]
    hook.Run('OnCharacterDelete', actor, id, character)

    Characters.delete(actor, id)
  end)

  Cable.receive('fl_player_select_character', function(actor, id)
    if !isnumber(id) or !istable(actor.record) then return end

    if is_throttled(actor) then
      refuse_request(actor, 'select', 'error.wait')

      return
    end

    local allowed, reason, arguments = Characters.can_use(actor, actor:get_character_by_id(id))

    if !allowed then
      refuse_request(actor, 'select', reason, arguments)

      return
    end

    Flux.dev_print(actor:name()..' has loaded character #'..id)

    actor:set_active_character(id)
  end)

  Cable.receive('fl_character_physdesc', function(actor, text)
    Characters.change_desc(actor, text)
  end)
else
  Cable.receive('fl_characters_load', function(data)
    --- Stores the list on the local player, once that player exists.
    -- @return [Boolean true when the list has been stored]
    local function store_characters()
      if !IsValid(PLAYER) then return false end

      PLAYER.characters = data

      timer.Remove('fl_characters_defer')

      --- Called on the client when the list of the local player's characters has arrived
      -- from the server and has been stored in PLAYER.characters. The server sends it when
      -- the player joins and again whenever one of their characters is created, deleted or
      -- changed. The list is stored as soon as it arrives, so the messages that the server
      -- sends after it are handled with the new list in place; only while the local player
      -- does not exist yet is it held back.
      -- @param characters [List<Map> networked data of every character of the local player]
      hook.Run('OnCharactersReceived', data)

      return true
    end

    if !store_characters() then
      timer.Create('fl_characters_defer', 0.1, 0, store_characters)
    end
  end)

  Cable.receive('fl_create_character', function(data)
    PLAYER.characters = PLAYER.characters or {}
    table.insert(PLAYER.characters, data)
  end)

  Cable.receive('fl_character_data', function(character_id, key, value)
    local character = IsValid(PLAYER) and PLAYER:get_character_by_id(character_id)

    if character then
      character.custom_data = character.custom_data or {}
      character.custom_data[key] = value
    end
  end)

  Cable.receive('fl_character_request_failed', function(action, reason, arguments)
    local text = t(reason, arguments)

    if IsValid(Flux.intro_panel) and isfunction(Flux.intro_panel.notify) then
      Flux.intro_panel:notify(text)
    elseif IsValid(PLAYER) then
      PLAYER:notify(text)
    end

    --- Called on the client when the server has refused a request of the local player to
    -- load or delete one of their characters, after the reason has been shown to them. The
    -- character loading screen uses it to bring back the card of a character that was not
    -- deleted.
    -- @param action [String 'select' or 'delete']
    -- @param text [String the translated reason]
    hook.Run('CharacterRequestFailed', action, text)
  end)

  Cable.receive('fl_character_menu', function(message, arguments)
    local menu = Flux.intro_panel

    if !IsValid(menu) then
      menu = Theme.create_panel('main_menu')

      Flux.intro_panel = menu
    elseif isfunction(menu.RecreateSidebar) and !IsValid(menu.menu) then
      menu:RecreateSidebar(true)
    end

    if message and IsValid(menu) and isfunction(menu.notify) then
      menu:notify(t(message, arguments))
    end
  end)

  Cable.receive('fl_character_desc_prompt', function()
    local confirm_text = t'ui.char_desc.confirm'

    Derma_StringRequest(
      t'ui.char_desc.title',
      t('ui.char_desc.message', {
        min = config_get('character_min_desc_len'),
        max = config_get('character_max_desc_len')
      }),
      PLAYER:get_phys_desc(),
      function(text)
        cable_send('fl_character_physdesc', text)
      end,
      nil,
      confirm_text
    )
  end)
end

do
  local player_meta = FindMetaTable('Player')

  --- Finds one of the player's own characters by its ID.
  -- @param id [Number character ID]
  -- @return [Character/Map the character record on the server or its networked data on the
  --   client, nil if the player has no such character]
  function player_meta:get_character_by_id(id)
    local characters = self:get_all_characters()

    for i = 1, #characters do
      local character = characters[i]

      if id == tonumber(character.id) then
        return character
      end
    end
  end

  --- Returns the networked ID of the player's active character.
  -- @return [Number character ID, or nil if no character has been selected]
  function player_meta:get_character_id()
    return self:get_nv('active_character')
  end

  --- Returns the player's active character. Bots get a plain table that is created on demand.
  -- @return [Character/Map the character record on the server or its networked data on the
  --   client, nil if no character is active]
  function player_meta:get_character()
    if SERVER and self.current_character then
      return self.current_character
    elseif self:IsBot() then
      self.char_data = self.char_data or {}

      return self.char_data
    end

    return self:get_character_by_id(self:get_character_id())
  end

  --- Checks whether the player has an active character. Always true for bots.
  -- @return [Boolean true if a character is active, false or nil otherwise]
  function player_meta:is_character_loaded()
    if self:IsBot() then return true end

    local id = self:get_character_id()

    return id and id > 0
  end

  --- Returns a field of the player's active character. On the client the value is read from
  -- the player's networked variable of the same name instead.
  -- @param id [String field name]
  -- @param default=nil [Any value to return when the field is not set]
  -- @return [Any]
  function player_meta:get_character_var(id, default)
    if SERVER then
      return self:get_character()[id] or default
    else
      return self:get_nv(id, default)
    end
  end

  --- Returns a value from the generic data of the player's active character. The server
  -- knows all of it; a client only knows the keys registered with
  -- `Characters.network_data`, and only for the local player.
  -- ```
  -- local position = target:get_character_data('spawn_position')
  -- ```
  -- @param key [String]
  -- @param default=nil [Any value to return when nothing is stored under the key or no
  --   character is active]
  -- @return [Any]
  -- @see [Characters.get_custom_data]
  function player_meta:get_character_data(key, default)
    if !self:is_character_loaded() then return default end

    return Characters.get_custom_data(self:get_character(), key, default)
  end

  --- Checks whether the player's active character is banned. A player whose active character
  -- gets banned stays dead until they load another one. On the client only the local player
  -- can be checked.
  -- @return [Boolean false when the player has no active character]
  function player_meta:is_character_banned()
    if !self:is_character_loaded() then return false end

    local character = self:get_character()

    return character != nil and tobool(character.banned)
  end

  --- Returns the physical description of the player's character.
  -- @return [String the description, or a placeholder text if none is set]
  function player_meta:get_phys_desc()
    return self:get_character_var('phys_desc', 'This character has no description!')
  end

  --- Returns the gender of the player's character as a string.
  -- @return [String 'male', 'female' or 'no_gender']
  function player_meta:get_gender()
    return translate_gender[self:get_character_var('gender', CHAR_GENDER_NONE)]
  end

  --- Returns all characters that belong to the player. Clients only know their own characters.
  -- @return [List character records on the server, networked character data on the client]
  function player_meta:get_all_characters()
    if SERVER then
      return self.record.characters
    else
      self.characters = self.characters or {}
      return self.characters
    end
  end
end
