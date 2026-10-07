local last_class = nil

--- Creates a new class. Supports constructors and inheritance.
-- The class is stored in the global table, or inside of another table when the name is
-- namespaced with `::`. Every class gets a `new` function that creates an instance and calls
-- its `init` constructor, and an `include` method that mixes a module into the class.
-- ```
-- class 'Animal'
--
-- function Animal:init(name)
--   self.name = name
-- end
--
-- class 'Dog' extends 'Animal'
--
-- function Dog:init(name)
--   super(name) -- calls Animal's constructor on the new object
-- end
--
-- Dog:include 'Talkable' -- copies missing methods from the Talkable module
--
-- local dog = Dog.new('Rex')
-- ```
-- @param name [String class name in ConstantStyle, may be namespaced (e.g. 'ActiveRecord::Model')]
-- @param parent_class=nil [String/Hash base class or its name]
-- @return [Hash the created class]
-- @see [extends]
-- @see [mod]
function class(name, parent_class)
  if isstring(parent_class) then
    parent_class = parent_class:parse_table()
  end

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

  -- If this class is based off some other class - copy its parent's data.
  if istable(parent_class) then
    local copy = table.Copy(parent_class)
    table.safe_merge(copy, obj)

    if isfunction(parent_class.class_extended) then
      local success, exception = pcall(parent_class.class_extended, parent_class, copy)

      if !success then
        error_with_traceback(tostring(exception))
      end
    end

    obj = copy
  end

  last_class = { name = name, parent = parent }

  obj.new = function(...)
    local new_obj = {}
    local real_class = parent[name]
    local old_super = super

    -- Set new object's meta table and copy the data from original class to new object.
    setmetatable(new_obj, real_class)
    table.safe_merge(new_obj, real_class)

    local parent_class = real_class.parent

    if parent_class and isfunction(parent_class.init) then
      super = function(...)
        return parent_class.init(new_obj, ...)
      end

      real_class.init = isfunction(real_class.init) and real_class.init or function(obj) super() end
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

--- Copies the listed methods of a class onto another object.
-- ```
-- -- MyLibrary.now and MyLibrary.tomorrow now point to the DateTime functions.
-- delegate(MyLibrary, { 'now', 'tomorrow', to = 'DateTime' })
-- ```
-- @param obj [Hash object or class that receives the methods]
-- @param t [Hash method names as array elements, the source class or its name in the `to` key]
-- @return [Boolean true, or nil if obj or t is not a table or `to` is missing]
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

--- Sets the base class of the class that is currently being created.
-- Copies the base class into the class created by the last `class` call, then calls the
-- base class's `class_extended(new_class)` method and runs the OnClassExtended hook.
-- ```
-- class 'DateTime' extends 'Date'
--
-- -- The base class can also be passed as a table.
-- class 'Dog' extends(Animal)
-- ```
-- @param parent_class [String/Hash base class or its name]
-- @return [Boolean whether or not did the extension succeed]
-- @see [class]
function extends(parent_class)
  if isstring(parent_class) then
    parent_class = parent_class:parse_table()
  end

  if istable(last_class) and istable(parent_class) then
    local obj = last_class.parent[last_class.name]
    local copy = table.Copy(parent_class)

    table.safe_merge(copy, obj)

    if isfunction(parent_class.class_extended) then
      local success, exception = pcall(parent_class.class_extended, parent_class, copy)

      if !success then
        error_with_traceback(tostring(exception))
      end
    end

    obj = copy
    obj.parent = parent_class
    obj.BaseClass = obj.parent_class

    hook.run('OnClassExtended', obj, parent_class)

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
