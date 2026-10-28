--- Modules: named tables of functions that are created with `mod` and can be mixed into each
-- other or into classes with `include`.
-- Libraries such as `Plugin`, `Config` and `Pipeline` are declared this way.

local function include_module(self, what)
  local module_table = isstring(what) and what:parse_table() or what

  if !istable(module_table) then return end

  for member_name, member in pairs(module_table) do
    if !self[member_name] then
      self[member_name] = member
    end
  end

  local included_modules = self.included_modules

  included_modules[#included_modules + 1] = module_table
end

--- Create a module with a specified name, or return the module that already exists under
-- that name, so that a refreshed file keeps the state of its module.
-- The resulting object will have the `include` method by default.
-- ```
-- mod 'Talkable'
--
-- -- You can include other modules too.
-- Talkable:include 'Living'
--
-- function Talkable:talk()
--   -- ...
-- end
-- ```
-- @param name [String module name in ConstantStyle, may be namespaced (e.g. 'Flux::Anim')]
-- @return [Object created module]
function mod(name)
  local parent, module_name = name:parse_parent()

  if module_name[1]:is_lower() then
    error('bad module name ('..module_name..')\nmodule names must follow the ConstantStyle!\n')
  end

  local obj = name:parse_table()

  if !obj then
    obj = {}
    parent[module_name] = obj
  end

  obj.included_modules = obj.included_modules or {}

  if !obj.include then
    obj.include = include_module
  end

  return obj
end
