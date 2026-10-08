--- Creates the `Flux` global together with `Flux.shared`, the table of data that the server
-- passes on to clients: the schema folder, plugin info, configs, dependencies and packages.
-- Refuses to start when the gamemode is set to 'flux' itself instead of a schema. On the
-- client it also loads the UTF-8 and SFS libraries and the generated files from
-- `_flux/client`.

if engine.ActiveGamemode() == 'flux' then
  error(txt[[
    ============================================
             +gamemode is set to 'flux'
    Set it to your schema's folder name instead!
    ============================================
  ]])

  return
end

if !Flux then
  Flux = {
    schema = engine.ActiveGamemode(),
    shared = {
      schema_folder     = engine.ActiveGamemode(),
      plugin_info       = {},
      unloaded_plugins  = {},
      configs           = {},
      deps_info         = {},
      packages          = {}
    }
  }
end

if CLIENT then
  local sfs_path, utf8_path = getenv('SFS_PATH'), getenv('UTF8_PATH')

  -- Include the required UTF-8 library.
  if !string.utf8upper then
    include(utf8_path..'lib/utf8.min.lua')
  end

  if !sfs then
    sfs = include(sfs_path..'lib/sfs.lua')
  end

  local files, folders = file.Find('_flux/client/*.lua', 'LUA')

  for k, v in ipairs(files) do
    include('_flux/client/'..v)
  end
end
