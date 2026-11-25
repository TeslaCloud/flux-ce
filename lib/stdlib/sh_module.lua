--- Modules: named tables of functions that are created with `mod` and can be mixed into each
-- other or into classes with `include`.
-- Libraries such as `Plugin`, `Config` and `Pipeline` are declared this way.

--- Create a module with a specified name, or return the module that already exists under
-- that name, so that a refreshed file keeps the state of its module.
-- A namespaced module is created inside of the table its name points to, which has to exist.
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
  local path = name:split('::')
  local module_name = table.remove(path)

  if module_name[1]:is_lower() then
    error('bad module name ('..module_name..')\nmodule names must follow the ConstantStyle!\n')
  end

  local obj = name:parse_table()

  if !obj then
    local parent, missing = _G, nil

    if #path > 0 then
      parent, missing = table.concat(path, '::'):parse_table()
    end

    if !parent then
      error('cannot create module '..name..', '..missing..' does not exist\n')
    end

    obj = {}
    parent[module_name] = obj
  end

  obj.included_modules = obj.included_modules or {}

  if !obj.include then
    obj.include = include_module
  end

  return obj
end
