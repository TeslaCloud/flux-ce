--- Extensions of the `player` library: picking a random player, finding players by a part of
-- their name, by their exact name or by SteamID, checking and normalizing SteamIDs, and looking
-- up the Steam name of a SteamID.

--- Selects a random player.
-- @return [Player random player, or nil if there are no players on the server]
function player.random()
  local all_ply = player.GetAll()

  if #all_ply > 0 then
    return all_ply[math.random(1, #all_ply)]
  end
end

--- Finds a player based on their name or SteamID.
-- A SteamID has to match exactly. A name is searched for as plain text in both the name and
-- the Steam name of every player; Steam names are always matched case-insensitively.
-- @param name [String/Player part of a name, or a SteamID; a valid player is returned as-is]
-- @param case_sensitive=false [Boolean match player names case-sensitively]
-- @param return_first=false [Boolean return the first match instead of all of them]
-- @return [Player/List<Player> the only match, an array if several players match, nil if none do]
function player.find(name, case_sensitive, return_first)
  if name == nil then return end
  if !isstring(name) then return (IsValid(name) and name) or nil end

  local hits = {}
  local is_steamid = name:start_with('STEAM_')
  local lower_name

  for _, client in player.Iterator() do
    if is_steamid then
      if client:SteamID() == name then
        return client
      end

      continue
    end

    local char_name = client:name(true)

    if char_name:find(name, 1, true) then
      hits[#hits + 1] = client
    else
      lower_name = lower_name or name:utf8lower()

      if !case_sensitive and char_name:utf8lower():find(lower_name, 1, true) then
        hits[#hits + 1] = client
      elseif client:steam_name():utf8lower():find(lower_name, 1, true) then
        hits[#hits + 1] = client
      end
    end

    if return_first and #hits > 0 then
      return hits[1]
    end
  end

  if #hits > 1 then
    return hits
  else
    return hits[1]
  end
end

--- Finds the players a name stands for when it has to match exactly, as for the player
-- arguments of commands. A SteamID ('STEAM_0:1:12345', in any case) or SteamID64 finds the
-- player who has it. Any other name is compared, ignoring the case, with the character name
-- of every player (their name without the 'GetPlayerName' hook) and, if no character name is
-- equal to it, with their Steam names. Several players can share a name; all of them are
-- returned then.
-- @param name [String SteamID, SteamID64, character name or Steam name]
-- @return [List<Player> the players, empty if nobody has this name]
function player.find_exact(name)
  local found = {}

  if !isstring(name) or name == '' then return found end

  local lower = name:utf8lower()

  if lower:sub(1, 6) == 'steam_' or (#name == 17 and tonumber(name)) then
    local upper = name:upper()

    for _, client in player.Iterator() do
      if client:SteamID() == upper or client:SteamID64() == name then
        found[#found + 1] = client

        return found
      end
    end

    return found
  end

  local by_steam_name = {}

  for _, client in player.Iterator() do
    if client:name(true):utf8lower() == lower then
      found[#found + 1] = client
    elseif client:steam_name():utf8lower() == lower then
      by_steam_name[#by_steam_name + 1] = client
    end
  end

  if #found > 0 then
    return found
  end

  return by_steam_name
end

--- Checks whether a value has the form of a SteamID, such as 'STEAM_0:1:12345'.
-- @param text [Any]
-- @return [Boolean]
function player.is_steam_id(text)
  return isstring(text) and text:match('^STEAM_%d:[01]:%d+$') != nil
end

--- Brings a SteamID into the form the engine gives it, upper case and with the universe digit
-- 0, so that 'steam_1:1:12345' becomes 'STEAM_0:1:12345'. Anything that is not a SteamID in
-- any case is returned as it is.
-- @param text [Any]
-- @return [Any the SteamID in the engine's form, or text]
function player.normalize_steam_id(text)
  if !isstring(text) then return text end

  local upper = text:upper()

  if !player.is_steam_id(upper) then return text end

  return (upper:gsub('^STEAM_%d:', 'STEAM_0:', 1))
end

--- Requests the Steam name that belongs to a SteamID through steamworks.
-- The request is asynchronous, so the name is only returned if it is available right away.
-- @param steamid [String SteamID, e.g. 'STEAM_0:1:12345678']
-- @return [String Steam name, or nil if it has not been received by the time this returns]
function player.name_from_steamid(steamid)
  local steam64 = util.SteamIDTo64(steamid)
  local steam_name

  steamworks.RequestPlayerInfo(steam64, function(_steam_name)
    steam_name = _steam_name
  end)

  return steam_name
end
