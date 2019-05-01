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
  -- Include the required the UTF-8 library.
  if !string.utf8upper then
    include 'flux/crates/utf8/lib/utf8.min.lua'
  end

  if !table.deserialize then
    include 'flux/crates/pon/lib/pon.min.lua'
    include 'flux/crates/flow/lib/sh_table.lua'
    include 'flux/crates/flow/lib/sh_library.lua'
    include 'flux/crates/flow/lib/sh_class.lua'
    include 'flux/crates/flow/lib/sh_helpers.lua'
  end

  local files, folders = file.Find('_flux/client/*.lua', 'LUA')

  for k, v in ipairs(files) do
    include('_flux/client/'..v)
  end
end
