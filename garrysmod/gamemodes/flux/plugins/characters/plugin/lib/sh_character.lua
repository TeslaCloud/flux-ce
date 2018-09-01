library.new "character"

local stored = character.stored or {}
character.stored = stored

function character.Create(player, data)
  if (!isstring(data.name) or (data.name:utf8len() < config.Get("character_min_name_len")
    or data.name:utf8len() > config.Get("character_max_name_len"))) then
    return CHAR_ERR_NAME
  end

  if (!isstring(data.phys_desc) or (data.phys_desc:utf8len() < config.Get("character_min_desc_len")
    or data.phys_desc:utf8len() > config.Get("character_max_desc_len"))) then
    return CHAR_ERR_DESC
  end

  if (!isnumber(data.gender) or (data.gender < CHAR_GENDER_MALE or data.gender > CHAR_GENDER_NONE)) then
    return CHAR_ERR_GENDER
  end

  if (!isstring(data.model) or data.model == "") then
    return CHAR_ERR_MODEL
  end

  local hooked, result = hook.run("PlayerCreateCharacter", player, data)

  if (hooked == false) then
    return result or CHAR_ERR_UNKNOWN
  end

  local char = Character.new()
  local steam_id = player:SteamID()

  char.steam_id = steam_id
  char.name = data.name
  char.user_id = player.record.id
  char.model = data.model or ''
  char.phys_desc = data.phys_desc or ''
  char.money = data.money or ''

  stored[steam_id] = stored[steam_id] or {}

  char.character_id = #stored[steam_id] + 1

  table.insert(stored[steam_id], char)

  if SERVER then
    local charID = #stored[steam_id]

    hook.run("PostCreateCharacter", player, charID, char)

    character.Save(player, charID)
  end

  return CHAR_SUCCESS
end

if SERVER then
  function character._add(steam_id, character_id, obj)
    stored[steam_id] = stored[steam_id] or {}
    stored[steam_id][character_id] = obj
  end

  function character.Load(player)
    local characters = player.record.characters or {}
  
    for k, v in pairs(characters) do
      character._add(player:SteamID(), v.character_id, v)
    end

    hook.run("PostRestoreCharacters", player)
  end

  function character.SendToClient(player)
    netstream.Start(player, "fl_loadcharacters", character.to_networkable(player))
  end

  function character.to_networkable(player)
    local characters = player.record.characters or {}
    local ret = {}
    for k, v in pairs(characters) do
      ret[k] = character.ToSaveable(player, v)
    end
    return ret
  end

  function character.ToSaveable(player, char)
    if (!IsValid(player) or !char) then return end

    return {
      steam_id = player:SteamID(),
      name = char.name,
      phys_desc = char.phys_desc or "This character has no physical description set!",
      model = char.model or "models/humans/group01/male_02.mdl",
      inventory = util.TableToJSON(char.inventory),
      ammo = util.TableToJSON(player:GetAmmoTable()),
      money = char.money,
      data = util.TableToJSON(char.data),
      character_id = char.character_id,
      user_id = char.user_id
    }
  end

  function character.Save(player, index)
    if (!IsValid(player) or !isnumber(index) or hook.run("PreSaveCharacter", player, index) == false) then return end

    local char = stored[player:SteamID()][index]

    hook.run("SaveCharaterData", player, char)

    char:save()

    hook.run("PostSaveCharacter", player, char)
  end

  function character.SaveAll(player)
    if (!IsValid(player)) then return end

    for k, v in ipairs(stored[player:SteamID()]) do
      character.Save(player, k)
    end
  end

  function character.Get(player, index)
    local steam_id = player:SteamID()

    if (stored[steam_id][index]) then
      return stored[steam_id][index]
    end
  end

  function character.set_name(player, index, newName)
    local char = character.Get(player, index)

    if (char) then
      char.name = newName or char.name

      player:set_nv("name", char.name)

      character.Save(player, index)
    end
  end

  function character.SetModel(player, index, model)
    local char = character.Get(player, index)

    if (char) then
      char.model = model or char.model

      player:set_nv("model", char.model)
      player:SetModel(char.model)

      character.Save(player, index)
    end
  end
else
  netstream.Hook("fl_loadcharacters", function(data)
    stored[fl.client:SteamID()] = stored[fl.client:SteamID()] or {}
    stored[fl.client:SteamID()] = data
  end)
end

if SERVER then
  netstream.Hook("CreateCharacter", function(player, data)
    data.gender  = (data.gender and data.gender == "Female" and CHAR_GENDER_FEMALE) or CHAR_GENDER_MALE
    data.phys_desc = data.description

    local status = character.Create(player, data)

    fl.dev_print("Creating character. Status: "..status)

    if (status == CHAR_SUCCESS) then
      character.SendToClient(player)
      netstream.Start(player, "PlayerCreatedCharacter", true, status)

      fl.dev_print("Success")
    else
      netstream.Start(player, "PlayerCreatedCharacter", false, status)

      fl.dev_print("Error")
    end
  end)

  netstream.Hook("PlayerSelectCharacter", function(player, id)
    fl.dev_print(player:Name().." has loaded character #"..id)

    player:SetActiveCharacter(id)
  end)
end

do
  local player_meta = FindMetaTable("Player")

  function player_meta:GetActiveCharacterID()
    return self:get_nv("ActiveCharacter", nil)
  end

  function player_meta:GetCharacterKey()
    return self:get_nv("key", -1)
  end

  function player_meta:CharacterLoaded()
    if (self:IsBot()) then return true end

    local id = tonumber(self:GetActiveCharacterID())

    return id and id > 0
  end

  function player_meta:GetInventory()
    return self:get_nv("inventory", {})
  end

  function player_meta:GetPhysDesc()
    return self:get_nv("phys_desc", "This character has no description!")
  end

  function player_meta:GetCharacterVar(id, default)
    if SERVER then
      return self:GetCharacter()[id] or default
    else
      return self:get_nv(id, default)
    end
  end

  function player_meta:GetCharacterData(key, default)
    return self:GetCharacterVar("data", {})[key] or default
  end

  function player_meta:GetCharacter()
    local charID = self:GetActiveCharacterID()

    if (charID) then
      return stored[self:SteamID()][charID]
    end

    if (self:IsBot()) then
      self.charData = self.charData or {}

      return self.charData
    end
  end

  function player_meta:GetAllCharacters()
    return stored[self:SteamID()] or {}
  end
end
