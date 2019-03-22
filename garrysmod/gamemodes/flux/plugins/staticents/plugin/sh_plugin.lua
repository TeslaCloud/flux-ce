PLUGIN:set_global('StaticEnts')

require_relative('sv_hooks.lua')

function StaticEnts:RegisterPermissions()
  Bolt:register_permission('static_tool', 'Static (tool)', 'Grants access to make entities static / unstatic.', 'categories.level_design', 'assistant')
end
