PLUGIN:set_global('Mapscenes')

Mapscenes.points = Mapscenes.points or {}

require_relative('cl_hooks.lua')
require_relative('cl_plugin.lua')
require_relative('sv_plugin.lua')

function Mapscenes:RegisterPermissions()
  Bolt:register_permission('mapscenes', 'Manage mapscenes', 'Grants access to manage mapscenes.', 'categories.level_design', 'moderator')
end
