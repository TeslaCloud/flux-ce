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

require_relative 'sh_config'
require_relative 'cl_hooks'
require_relative 'cl_plugin'
require_relative 'sv_hooks'
require_relative 'sv_plugin'

function Doors:RegisterPermissions()
  Bolt:register_permission('manage_doors', 'Doors settings access', 'Grants access to customize doors.', 'categories.level_design', 'assistant')
end

function Doors:OnPluginsLoaded()
  hook.run('RegisterDoorProperties')
  hook.run('RegisterDoorTitleTypes')
end
