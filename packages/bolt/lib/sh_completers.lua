--- Completers of the argument types that Bolt's commands use: 'duration' (a few examples of
-- the durations that `Bolt:interpret_ban_time` reads), 'permission' (every registered
-- permission), 'role' (every registered role) and 'map' (the maps of the server).

local duration_examples = { '30', '1 hour', '1 day', '1 week', '1 month', 'perma' }

--- Suggests a few durations for the arguments of the 'duration' type, which are read with
-- `Bolt:interpret_ban_time`: a bare number is minutes, and 'perma' stands for a permanent
-- duration.
-- @return [List<String>]
local function complete_duration()
  return duration_examples
end

local function complete_permission()
  local ids = {}

  for id in pairs(Bolt:get_all_permissions()) do
    ids[#ids + 1] = id
  end

  table.sort(ids)

  return ids
end

local function complete_role()
  local ids = {}

  for id in pairs(Bolt:get_roles()) do
    ids[#ids + 1] = id
  end

  table.sort(ids)

  return ids
end

Flux.Command:add_completer('duration', complete_duration)
Flux.Command:add_completer('permission', complete_permission)
Flux.Command:add_completer('role', complete_role)
Flux.Command:add_completer('map', game.get_maps)
