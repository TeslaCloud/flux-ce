-- A function to select a random player.
function player.random()
  local allPly = player.GetAll()

  if #allPly > 0 then
    return allPly[math.random(1, #allPly)]
  end
end

-- A function to find player based on their name or steam_id.
function player.find(name, case_sensitive, return_first)
  if name == nil then return end
  if !isstring(name) then return (IsValid(name) and name) or nil end

  local hits = {}
  local isSteamID = name:starts('STEAM_')

  for k, v in ipairs(_player.GetAll()) do
    if isSteamID then
      if v:SteamID() == name then
        return v
      end

      continue
    end

    if v:Name(true):find(name) then
      table.insert(hits, v)
    elseif !case_sensitive and v:Name(true):utf8lower():find(name:utf8lower()) then
      table.insert(hits, v)
    elseif v:SteamName():utf8lower():find(name:utf8lower()) then
      table.insert(hits, v)
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
