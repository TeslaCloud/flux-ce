local last_class = nil

--
-- Function: class(string name, table parent = _G, class base_class = nil)
-- Description: Creates a new class. Supports constructors and inheritance.
-- Argument: string name - The name of the library. Must comply with Lua variable name requirements.
-- Argument: table parent (default: _G) - The parent table to put the class into.
-- Argument: class base_class (default: nil) - The base class this new class should extend.
--
-- Alias: class (string name, class base_class = nil, table parent = _G)
--
-- Returns: table - The created class.
--
function class(name, base_class)
  if isstring(base_class) then
    base_class = base_class:parse_table()
  end

  local parent = nil
  parent, name = name:parse_parent()
  parent[name] = {}

  if name[1]:is_lower() then
    error('bad class name ('..name..')\nclass names must follow the ConstantStyle!\n')
  end

  local obj = parent[name]
  obj.ClassName = name
  obj.BaseClass = base_class or false
  obj.class_name = obj.ClassName
  obj.base_class = obj.BaseClass
  obj.static_class = true
  obj.class = obj

  -- If this class is based off some other class - copy it's parent's data.
  if istable(base_class) then
    local copy = table.Copy(base_class)
    table.safe_merge(copy, obj)

    if isfunction(base_class.class_extended) then
      try {
        base_class.class_extended, base_class, copy
      } catch {
        function(exception)
          ErrorNoHalt(tostring(exception) + '\n')
        end
      }
    end

    obj = copy
  end

  last_class = { name = name, parent = parent }

  obj.new = function(...)
    local new_obj = {}
    local real_class = parent[name]

    -- Set new object's meta table and copy the data from original class to new object.
    setmetatable(new_obj, real_class)
    table.safe_merge(new_obj, real_class)

    -- If there is a base class, call their constructor.
    local base_class = real_class.BaseClass
    local has_base_class = true

    while istable(base_class) and has_base_class do
      if base_class.BaseClass and base_class.ClassName != base_class.BaseClass.ClassName then
        base_class = base_class.BaseClass
      else
        has_base_class = false
      end
    end

    -- If there is a constructor - call it.
    if real_class.init then
      local success, value = pcall(real_class.init, new_obj, ...)

      if !success then
        ErrorNoHalt('['..name..'] Class constructor has failed to run!\n')
        ErrorNoHalt(value..'\n')
      end
    end

    new_obj.class = real_class
    new_obj.static_class = false
    new_obj.IsValid = function() return true end

    -- Return our newly generated object.
    return new_obj
  end

  obj.include = function(self, what)
    local module_table = isstring(what) and what:parse_table() or what

    if !istable(module_table) then return end

    for k, v in pairs(module_table) do
      if !self[k] then
        self[k] = v
      end
    end
  end

  return parent[name]
end

function delegate(obj, t)
  if !istable(obj) or !istable(t) or !t.to then return end

  local class = isstring(t.to) and t.to:parse_table() or t.to

  if istable(class) and class.class_name then
    for k, v in ipairs(t) do
      obj[v] = class[v]
    end
  end

  return true
end

--
-- Function: extends (class base_class)
-- Description: Sets the base class of the class that is currently being created.
-- Argument: class base_class - The base class to extend.
--
-- Alias: implements
-- Alias: inherits
--
-- Returns: bool - Whether or not did the extension succeed.
--
function extends(base_class)
  if isstring(base_class) then
    base_class = base_class:parse_table()
  end

  if istable(last_class) and istable(base_class) then
    local obj = last_class.parent[last_class.name]
    local copy = table.Copy(base_class)

    table.safe_merge(copy, obj)

    if isfunction(base_class.class_extended) then
      try {
        base_class.class_extended, base_class, copy
      } catch {
        function(exception)
          ErrorNoHalt(tostring(exception) + '\n')
        end
      }
    end

    obj = copy
    obj.BaseClass = base_class
    obj.base_class = obj.BaseClass

    hook.run('OnClassExtended', obj, base_class)

    last_class.parent[last_class.name] = obj
    last_class = nil

    return true
  end

  return false
end

--
-- class 'SomeClass' extends SomeOtherClass
-- class 'SomeClass' extends 'SomeOtherClass'
--
