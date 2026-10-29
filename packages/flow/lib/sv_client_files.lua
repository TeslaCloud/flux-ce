--- Writes the Lua files that clients include when they load into `lua/_flux/client` and marks
-- them for download: the shared data, the settings without their serverside part, the
-- language phrases and whatever the `WriteClientFiles` handlers add, such as the compiled
-- templates of Lumen. The clients include the files in the order of their names, from
-- `lib/flux_struct.lua`.
-- @module [Flux]

local chunk_size = 100_000

local function purge_client_files()
  if file.Exists('lua/_flux/client', 'GAME') then
    local files = file.Find('lua/_flux/client/*', 'GAME')

    for _, file_name in ipairs(files) do
      File.delete('lua/_flux/client/'..file_name)
    end
  end
end

--- Writes a Lua file into lua/_flux/client and marks it for download, so that the clients
-- include it when they load. The files are included in the order of their names, which
-- is why the gamemode's own start with a number. Packages that generate clientside code
-- call this from their `WriteClientFiles` handler, since the folder is emptied before
-- the files are written.
-- @param path [String file name, relative to lua/_flux/client]
-- @param contents [String Lua code]
function Flux.write_client_file(path, contents)
  File.mkdir 'lua/_flux'
  File.mkdir 'lua/_flux/client'

  File.write('lua/_flux/client/'..path, contents)
  AddCSLuaFile('_flux/client/'..path)
end

--- Writes a table for the client, split over as many files as it takes. The pieces are put
-- back together by Flux.receive_chunk, 'assign' is the code that runs once 'data' is whole.
-- Garry's Mod does not send a Lua file to clients if it is larger than 64 KB once it is
-- compressed, clients get an empty file instead. Serialized tables are hex digits, which
-- compress to half their size at worst, so pieces of 100000 characters always stay below
-- that.
local function write_client_table(name, tab, assign)
  local contents = table.serialize(tab)
  local count = math.max(math.ceil(#contents / chunk_size), 1)

  for i = 1, count do
    Flux.write_client_file(
      string.format('%s_%02d.lua', name, i),
      "local data = Flux.receive_chunk('"..name.."', "..i..', '..count..', [['
        ..contents:sub((i - 1) * chunk_size + 1, i * chunk_size)..']])\n'
        ..'if data then '..assign..' end\n'
    )
  end
end

--- Empties lua/_flux/client and writes the files that get sent to clients again: the shared
-- data, the settings, the language phrases and whatever the WriteClientFiles handlers add.
function Flux.write_client_files()
  purge_client_files()

  local settings_copy = table.Copy(Settings)
  settings_copy.server = nil

  write_client_table('0_shared', Flux.shared, 'Flux.shared = data')
  write_client_table('1_settings', settings_copy, 'Settings = data')
  write_client_table('2_lang', Flux.Lang.stored, "mod'Flux::Lang' Flux.Lang.stored = data")

  --- Called on the server while the files that get sent to the clients are written, on
  -- `FluxPackageLoaded` and after a Lua refresh, once the shared data, the settings and
  -- the language phrases have been written. Packages and plugins that generate clientside
  -- code of their own, such as the compiled templates of Lumen, write it here with
  -- `Flux.write_client_file`.
  hook.Run('WriteClientFiles')
end
