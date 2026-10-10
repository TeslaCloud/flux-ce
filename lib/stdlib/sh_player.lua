--- Extensions of the `player` library: picking a random player, finding players by name or
-- SteamID and looking up the Steam name of a SteamID.

--- Selects a random player.
-- @return [Player random player, or nil if there are no players on the server]
function player.random()
  local all_ply = player.GetAll()

  if #all_ply > 0 then
    return all_ply[math.random(1, #all_ply)]
  end
end

--- Finds a player based on their name or SteamID.
-- A SteamID has to match exactly. A name is searched for as a Lua pattern in both the
-- name and the Steam name of every player; Steam names are always matched case-insensitively.
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

  for k, v in player.Iterator() do
    if is_steamid then
      if v:SteamID() == name then
        return v
      end

      continue
    end

    local char_name = v:name(true)

    if char_name:find(name) then
      hits[#hits + 1] = v
    else
      lower_name = lower_name or name:utf8lower()

      if !case_sensitive and char_name:utf8lower():find(lower_name) then
        hits[#hits + 1] = v
      elseif v:steam_name():utf8lower():find(lower_name) then
        hits[#hits + 1] = v
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
