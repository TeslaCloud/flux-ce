if !string.parse_parent then
  include 'sh_aliases.lua'
  include 'sh_string.lua'
end

function library(lib_name)
  local parent, name = lib_name:parse_parent()

  if name[1]:is_lower() then
    error('bad module name ('..name..')\nmodule names must follow the ConstantStyle!\n')
  end

  parent[name] = parent[name] or {}

  return parent[name]
end
