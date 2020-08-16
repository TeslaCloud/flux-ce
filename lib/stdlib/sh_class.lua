local last_class = nil

local extender = function(...)
  local info, r = {names = {}}, {}

  local merge
  merge = function(t, n)
    for k, it in next, t do
      if isclass(it) then
        info.names[{[1] = it.class_name, [2] = (n or it)}] = true

        table.merge(r, it)

        if isfunction(it.class_extended) then
          xpcall(it.class_extended, error_with_traceback, it, r)
        end
      elseif isstring(it) then
        for ti in it:gmatch "[%w_:]+" do
          merge({ti:parse_table()}, ti)
        end
      end
    end

    r.init = nil
  end

  merge {...}

  return r, info
end

local makeSuper = function(s)
  return setmetatable({}, {
    __index = function(self, key)
      for cls in next, s.parent_info.names do
        local t = (isstring(cls[2]) and cls[2]:parse_table() or cls[2])

        if t[key] then
          return t[key]
        end
        
        if istable(cls[2]) and cls[2].class_name == key or cls[2] == key then
          return t
        end
      end
    end,
    __call = function(self, ...)
      for cls in next, s.parent_info.names do
        local t = (isstring(cls[2]) and cls[2]:parse_table() or cls[2])

        if t.init then
          t.init(s)
        end
      end
    end
  })
end

--
-- Function: class(string name, table parent = _G, class parent_class = nil)
-- Description: Creates a new class. Supports constructors and inheritance.
-- Argument: string name - The name of the library. Must comply with Lua variable name requirements.
-- Argument: table parent (default: _G) - The parent table to put the class into.
-- Argument: class parent_class (default: nil) - The base class this new class should extend.
--
-- Alias: class (string name, class parent_class = nil, table parent = _G)
--
-- Returns: table - The created class.
--
function class(name, parent_class)
  local parent = nil
  parent, name = name:parse_parent()
  parent[name] = {}

  if name[1]:is_lower() then
    error('bad class name ('..name..')\nclass names must follow the ConstantStyle!\n')
  end

  local obj = parent[name]
  obj.ClassName = name
  obj.BaseClass = parent_class or false
  obj.class_name = obj.ClassName
  obj.parent = obj.BaseClass
  obj.static_class = true
  obj.class = obj
  obj.included_modules = {}
  obj.super = makeSuper(obj)

  -- If this class is based off some other class - copy it's parent's data.
  if istable(parent_class) or isstring(parent_class) then
    local copy, info = extender(parent_class)

    table.merge(copy, obj)

    table.safe_merge(obj, copy)
    obj.parent = parent
    obj.parent_info = info
    obj.BaseClass = obj.parent
  end

  last_class = { name = name, parent = parent }

  obj.new = function(...)
    local new_obj = {}
    local real_class = parent[name]
    local old_super = super

    -- Set new object's meta table and copy the data from original class to new object.
    setmetatable(new_obj, real_class)
    table.safe_merge(new_obj, real_class)

    if not table.IsEmpty(real_class.parent_info.names) then
      super = makeSuper(real_class)
      
      real_class.init = real_class.init or function(obj, ...) super(...) end
    end

    -- If there is a constructor - call it.
    if real_class.init then
      local success, value = pcall(real_class.init, new_obj, ...)

      if !success then
        ErrorNoHalt('['..name..'] Class constructor has failed to run!\n')
        error_with_traceback(value)
      end
    end

    new_obj.class = real_class
    new_obj.static_class = false
    new_obj.IsValid = function() return true end

    super = old_super

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

    table.insert(self.included_modules, module_table)
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
-- Function: extends (class parent_class)
-- Description: Sets the base class of the class that is currently being created.
-- Argument: class parent_class - The base class to extend.
--
-- Alias: implements
-- Alias: inherits
--
-- Returns: bool - Whether or not did the extension succeed.
--
function extends(...)
  local obj = last_class.parent[last_class.name]
  local parent, info = extender(...)

  table.merge(parent, obj)

  table.safe_merge(obj, parent)
  obj.parent = parent
  obj.parent_info = info
  obj.BaseClass = obj.parent

  hook.run('OnClassExtended', obj, parent)

  last_class.parent[last_class.name] = obj
  last_class = nil
end

--
-- class 'SomeClass' extends SomeOtherClass
-- class 'SomeClass' extends 'SomeOtherClass'
--
