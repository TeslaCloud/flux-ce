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
      deps_info         = {}
    }
  }
end

if CLIENT then
  -- Include the required third-party libraries.
  if !string.utf8upper or !pon or !Cable then
    include 'flux/lib/vendor/utf8.min.lua'
    include 'flux/lib/vendor/pon.min.lua'
    Cable     = include 'flux/lib/vendor/cable.min.lua'
    Markdown  = include 'flux/lib/vendor/markdown.min.lua'
  end

  if !table.deserialize then
    include 'flux/crates/flow/lib/sh_table.lua'
    include 'flux/crates/flow/lib/sh_library.lua'
  end

  local files, folders = file.Find('_flux/client/*.lua', 'LUA')

  for k, v in ipairs(files) do
    include('_flux/client/'..v)
  end
end
