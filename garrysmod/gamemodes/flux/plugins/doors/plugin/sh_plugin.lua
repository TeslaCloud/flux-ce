PLUGIN:set_global('Doors')

local conditions = condition or {}
local properties = Doors.properties or {}
local title_types = Doors.title_types or {}
condition = conditions
Doors.properties = properties
Doors.title_types = title_types

function Conditions:register(id, data)
  conditions[id] = data
end

function Doors:register_property(id, data)
  properties[id] = data
end

function Doors:register_title_type(id, data)
  title_types[id] = data
end

util.include('sh_config.lua')
util.include('cl_plugin.lua')
util.include('sv_hooks.lua')
util.include('sv_plugin.lua')
