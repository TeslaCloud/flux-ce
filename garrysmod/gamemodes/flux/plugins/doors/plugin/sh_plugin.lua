PLUGIN:set_global('Doors')

local properties = Doors.properties or {}
local title_types = Doors.title_types or {}
Doors.properties = properties
Doors.title_types = title_types

function Doors:register_property(id, data)
  properties[id] = data
end

function Doors:register_title_type(id, data)
  title_types[id] = data
end

require_relative('sh_config.lua')
require_relative('cl_hooks.lua')
require_relative('cl_plugin.lua')
require_relative('sv_hooks.lua')
require_relative('sv_plugin.lua')

function Doors:RegisterPermissions()
  Bolt:register_permission('manage_doors', 'Doors settings access', 'Grants access to customize doors.', 'categories.level_design', 'assistant')
end
