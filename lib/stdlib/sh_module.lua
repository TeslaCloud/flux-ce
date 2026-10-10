--- Modules: named tables of functions that are created with `mod` and can be mixed into each
-- other or into classes with `include`.
-- Libraries such as `Plugin`, `Config` and `Pipeline` are declared this way.

--- Create a module with a specified name.
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
  local parent = nil
  parent, name = name:parse_parent()
  parent[name] = parent[name] or {}

  if name[1]:is_lower() then
    error('bad module name ('..name..')\nmodule names must follow the ConstantStyle!\n')
  end

  local obj = {}

  obj.included_modules = {}

  obj.include = function(self, what)
    local module_table = isstring(what) and what:parse_table() or what

    if !istable(module_table) then return end

    for k, v in pairs(module_table) do
      if !self[k] then
        self[k] = v
      end
    end

    local included_modules = self.included_modules

    included_modules[#included_modules + 1] = module_table
  end

  parent[name] = obj

  return obj
end
