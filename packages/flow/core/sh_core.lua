--- Core helpers of the Flux gamemode package on the global `Flux` table.
-- They cover console output (`Flux.print`, `Flux.dev_print`), the registry of player
-- actions (`Flux.register_action`) and the global UI offset that HUD elements follow on the
-- client.
-- The same file replaces `file.Write` with a version that creates missing folders.
-- @module [Flux]

AddCSLuaFile()

local debug_color = Color(200, 200, 200)

--- Prints a message to the console. Tables are printed with PrintTable.
-- @param message [Any]
function Flux.print(message)
  if !istable(message) then
    print(message)
  else
    PrintTable(message)
  end
end

--- Prints a debug message to the console, but only in development or when the
-- debug_output_in_production setting is enabled.
-- @param message [String]
function Flux.dev_print(message)
  if Flux.development or Settings.debug_output_in_production then
    Msg('Debug: ')
    MsgC(debug_color, message)
    Msg('\n')
  end
end

file.old_write = file.old_write or file.Write

--- Writes a file to the data/ folder. This detour of the engine function also creates all
-- of the folders leading to the file. The original function is kept as file.old_write.
-- @param file_name [String path of the file, relative to data/]
-- @param contents [String]
function file.Write(file_name, contents)
  for slash in file_name:gmatch('()/') do
    local folder = file_name:sub(1, slash)

    if !file.Exists(folder, 'DATA') then
      file.CreateDir(folder)
    end
  end

  file.old_write(file_name, contents)
end

do
  local action_storage = Flux.action_storage or {}
  Flux.action_storage = action_storage

  --- Registers an action that can be assigned to a player. The value is stored as given;
  -- note that Player#do_action only runs it if it is a table with a callback function
  -- field, which is then called with the player and the action ID.
  -- @param id [String identifier of the action]
  -- @param callback=nil [Map/Function handler of the action, see above]
  function Flux.register_action(id, callback)
    action_storage[id] = callback
  end

  --- Retrieves whatever was registered for the action with the specified identifier.
  -- @param id [String identifier of the action]
  -- @return [Map/Function the registered value, or nil if there is none]
  function Flux.get_action(id)
    return action_storage[id]
  end

  --- Returns the table storing all of the actions, keyed by identifier. This is the storage
  -- table itself, not a copy.
  -- @return [Map]
  function Flux.get_all_actions()
    return action_storage
  end

  Flux.register_action('spawning')
  Flux.register_action('idle')
end

do
  local offset_x, offset_y = 0, 0

  --- Sets the offset returned by Flux.global_ui_offset.
  -- @warning [Internal]
  -- @param x [Number]
  -- @param y [Number]
  function Flux.__set_global_offset__(x, y)
    offset_x, offset_y = x, y
  end

  --- Returns the global UI offset, which follows the local player's view movement. HUD
  -- elements add it to their position to appear to lag behind the camera.
  -- @return [Number x offset, Number y offset]
  function Flux.global_ui_offset()
    return offset_x, offset_y
  end
end
