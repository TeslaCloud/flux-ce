--- Server side of the `Characters` functions: they create, save, delete, ban and edit
-- characters, keep the names that are taken, send the characters to their owners and check
-- the requests of players to load or delete a character.

local IsValid = IsValid
local isnumber = isnumber
local isstring = isstring
local istable = istable
local tobool = tobool
local tonumber = tonumber
local cable_send = Cable.send
local config_get = Config.get
local string_trim = string.Trim

--- The model of a character that has none of its own.
Characters.default_model = 'models/humans/group01/male_02.mdl'

Characters.taken_names = Characters.taken_names or {}

local request_delay = 1

--- Brings a character name to the form in which names are compared: lower case, without
-- surrounding whitespace and with every run of whitespace turned into a single space.
-- @param name [String]
-- @return [String]
local function normalize_name(name)
  return (string_trim(name):gsub('%s+', ' ')):utf8lower()
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

--- Returns the player a character belongs to, if they are on the server. A character whose
-- user record has no connected player belongs to the connected player who has it as their
-- active character, if there is one. Server only.
-- @param character [Character]
-- @return [Player the owner, or nil when nobody on the server has the character]
function Characters.get_owner(character)
  if !istable(character) then return end

  local user = character.user
  local owner = istable(user) and user.player

  if IsValid(owner) then
    return owner
  end

  for _, client in player.Iterator() do
    if client.current_character == character then
      return client
    end
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
    count -= 1
  end

  return count > 0
end

--- Finds the characters that have a name, compared without regard to letter case. The
-- characters of the user records that are loaded are searched first: those of connected
-- players and those that a AdjustLoadedUserRecords handler adds. Only when none of them
-- matches are the characters of offline players loaded from the database, which makes the
-- callback run later. Server only.
-- @param name [String]
-- @param callback [Function receives a List<Character>, empty when nothing was found]
-- @return [Any what the callback returns if a loaded character matches, nil otherwise]
function Characters.find_by_name(name, callback)
  local key = normalize_name(name)
  local found = {}
  local records = {}

  for _, client in player.Iterator() do
    if !client:IsBot() and istable(client.record) then
      records[#records + 1] = client.record
    end
  end

  --- Lets plugins add user records that are loaded although no connected player owns
  -- them, so that their characters are found in memory rather than loaded again from the
  -- database, or remove records from the search. Called on the server by
  -- `Characters.find_by_name`, with the records of the connected players already in the
  -- list. Handlers add or remove entries in place and return nothing.
  -- @param records [List<User> the records whose characters are searched, changed in place]
  hook.Run('AdjustLoadedUserRecords', records)

  for _, record in ipairs(records) do
    if istable(record.characters) then
      for _, character in ipairs(record.characters) do
        if isstring(character.name) and normalize_name(character.name) == key then
          found[#found + 1] = character
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
-- The text is brought to its stored form with `Characters.normalize_desc` and refused when
-- its length is outside of the `characters_min_desc_len` and `characters_max_desc_len` configs,
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

  local new_desc = Characters.normalize_desc(text)
  local length = utf8.len(new_desc)
  local min_length = config_get('characters_min_desc_len')
  local max_length = config_get('characters_max_desc_len')

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

  for index, character in pairs(characters) do
    ret[index] = Characters.to_networkable(target, character)
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
    model = char.model or Characters.default_model,
    skin = char.skin or 1,
    banned = tobool(char.banned),
    custom_data = get_networked_data(char)
  }
end

--- Runs the SaveCharacterData hook, saves the player's record to the database and runs the
-- PostSaveCharacter hook, unless a PreSaveCharacter hook returns false. A character that
-- belongs to another user record than the player's is saved on its own, together with its
-- own relations. Server only.
-- @param target [Player the player whose data goes into the character]
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

  if istable(character.user) and character.user != target.record and isfunction(character.save) then
    character:save()
  else
    target:save_player()
  end

  --- Called on the server by `Characters.save` once the record of a character has been handed
  -- to the database to be saved. Not called when `PreSaveCharacter` has canceled the save.
  -- @param owner [Player]
  -- @param character [Character the character that has been saved]
  hook.Run('PostSaveCharacter', target, character)
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

    for index, character in pairs(target:get_all_characters()) do
      if tonumber(character.id) == id then
        table.remove(target.record.characters, index)

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
  if !isstring(new_name) then return end

  local char = target:get_character()
  local old_name = target:get_nv('name')

  if char then
    if !target:IsBot() then
      Characters.forget_name(char.name)
      Characters.remember_name(new_name)
    end

    char.name = new_name
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
  if !isstring(new_desc) then return end

  local char = target:get_character()
  local old_desc = target:get_nv('phys_desc')

  if char then
    char.phys_desc = new_desc
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
  if !isstring(model) then return end

  local char = target:get_character()
  local old_model = target:get_nv('model')

  if char then
    char.model = model
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
  if isstring(new_gender) then
    new_gender = table.KeyFromValue(Characters.gender_names, new_gender)
  end

  if !new_gender then return end

  local char = target:get_character()
  local old_gender = target:get_nv('gender')

  if char then
    char.gender = new_gender
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

--- Creates a character for a player unless a PlayerCreateCharacter hook rejects the data.
-- The character is then saved and sent to its owner. Server only.
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
-- The new character belongs to the user record of the player unless a GetCharacterOwner hook
-- hands it to another `User` record; only for a character of the player's own is their
-- character list sent to them again.
-- @param target [Player the player the character is created for, its owner unless a
--   GetCharacterOwner hook names another record]
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

  --- Lets plugins give a character that is being created to another user record than the one
  -- of the player who creates it. Called by `Characters.create`, which the plugin runs on the
  -- server, once the creation data has passed the PlayerCreateCharacter hook. A character
  -- that belongs to another record is saved on its own and is not sent to the player.
  -- @param target [Player the player the character is created for]
  -- @param data [Map creation data the character is built from]
  -- @return [User the record that is to own the character; return nothing to let the player
  --   own it]
  local owner_record = hook.Run('GetCharacterOwner', target, data)
  local record = istable(owner_record) and owner_record or target.record

  record.characters = record.characters or {}

  local char = Character.new()
    char.steam_id = record.steam_id or target:SteamID()
    char.name = data.name
    char.model = data.model or ''
    char.skin = data.skin or 0
    char.gender = data.gender
    char.phys_desc = data.phys_desc or ''
    char.health = 100
    char.banned = false
    char.user = record
    char.user_id = record.id
  table.insert(record.characters, char)

  --- Called on the server when a character has been built and added to the record of its
  -- owner, before it is saved and sent to the owner. Handlers copy their own fields from the
  -- creation data to the character.
  -- @param owner [Player]
  -- @param char [Character the new character, not saved yet]
  -- @param char_data [Map creation data the character was built from]
  hook.Run('PostCreateCharacter', target, char, data)

  Characters.remember_name(char.name)
  Characters.save(target, char)

  if record == target.record then
    Characters.send_to_client(target)
  end

  return CHAR_SUCCESS
end
