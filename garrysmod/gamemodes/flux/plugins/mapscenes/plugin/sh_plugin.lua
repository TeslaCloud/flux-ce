PLUGIN:set_global('Mapscenes')

Mapscenes.points = Mapscenes.points or {}

util.include('cl_hooks.lua')
util.include('cl_plugin.lua')
util.include('sv_plugin.lua')

function Mapscenes:RegisterPermissions()
  Bolt:register_permission('mapscenes', 'Manage mapscenes', 'Grants access to manage mapscenes.', 'categories.level_design', 'moderator')
end
