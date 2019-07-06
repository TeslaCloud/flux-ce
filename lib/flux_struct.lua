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
    schema              = engine.ActiveGamemode(),
    shared = {
      schema_folder     = engine.ActiveGamemode(),
      plugin_info       = {},
      unloaded_plugins  = {},
      configs           = {},
      deps_info         = {},
      crates            = {}
    }
  }
end

if CLIENT then
  local pon_path, utf8_path = getenv('PON_PATH'), getenv('UTF8_PATH')

  -- Include the required the UTF-8 library.
  if !string.utf8upper then
    include(utf8_path..'lib/utf8.min.lua')
  end

  if !pon then
    include(pon_path..'lib/pon.min.lua')
  end

  local files, folders = file.Find('_flux/client/*.lua', 'LUA')

  for k, v in ipairs(files) do
    include('_flux/client/'..v)
  end
end
