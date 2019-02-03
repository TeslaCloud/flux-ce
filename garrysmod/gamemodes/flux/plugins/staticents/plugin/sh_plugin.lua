PLUGIN:set_global('StaticEnts')

util.include('sv_hooks.lua')

function StaticEnts:RegisterPermissions()
  Bolt:register_permission('static_tool', 'Static (tool)', 'Grants access to make entities static / unstatic.', 'categories.level_design', 'assistant')
end
