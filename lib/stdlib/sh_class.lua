--- Classes for Lua: the `class` keyword with constructors, inheritance through `extends` and
-- `super`, and mixins through `include`.
-- Classes are plain tables stored under their ConstantStyle name. Instances are created with
-- `Name.new(...)`, which copies the class into a new table and calls its `init` method.
-- `delegate` copies selected methods of a class to another object, and `isclass` tells
-- classes and their instances from other values.

local istable = istable
local isstring = isstring
local isfunction = isfunction
local pcall = pcall

local last_class = nil

local function always_valid()
  return true
end

--- Checks whether or not an object is a class or an instance of a class.
-- @param obj [Any object to check]
-- @return [Boolean whether or not the object is a class]
-- @see [class]
function isclass(obj)
  return istable(obj) and istable(obj.class) and isstring(obj.class_name)
end

--- Mixes a module into a class or another module: copies every member of the module that the
-- object does not have yet and adds the module to the `included_modules` list of the object.
-- Every class and every module has this function as its `include` method.
-- @param obj [Map class or module that receives the members]
-- @param what [String/Map the module or its name]
-- @see [mod]
function include_module(obj, what)
  local module_table = isstring(what) and what:parse_table() or what

  if !istable(module_table) then return end

  for member_name, member in pairs(module_table) do
    if !obj[member_name] then
      obj[member_name] = member
    end
  end

  local included_modules = obj.included_modules

  included_modules[#included_modules + 1] = module_table
end

--- Finds the base class given to a class by its name, and reports one that is not defined.
-- @param class_name [String name of the class that is being created]
-- @param base [String/Map/Nil the base class or its name]
-- @return [Map/Boolean the base class, or false if it is not defined]
local function find_base(class_name, base)
  if istable(base) then return base end

  local base_name = isstring(base) and base or tostring(base)
  local found = isstring(base) and base:parse_table()

  if !found then
    error_with_traceback(
      'class '..class_name.." extends '"..base_name.."', but "..base_name..' is not defined: include its file first'
    )
  end

  return found
end

--- Copies a base class into a class and announces the extension to the base class and to the
-- ClassExtended hook, both of which receive the class itself.
-- @param obj [Map the class that is being created]
-- @param base_class [Map the class it extends]
local function apply_base(obj, base_class)
  local copy = table.Copy(base_class)

  table.safe_merge(copy, obj)
  table.safe_merge(obj, copy)

  obj.parent = base_class
  obj.BaseClass = base_class

  if isfunction(base_class.class_extended) then
    local success, exception = pcall(base_class.class_extended, base_class, obj)

    if !success then
      error_with_traceback(tostring(exception))
    end
  end

  --- Called when a class is given a base class, with `extends` or with the second argument of
  -- `class`, after the base class has been copied into it.
  -- Runs on the realm the class is defined on.
  -- @param new_class [Map the class that is being created]
  -- @param parent_class [Map the base class it extends]
  hook.Run('ClassExtended', obj, base_class)
end

--- Runs the constructor of a class on the object being created. Inside of it, `super` runs the
-- constructor of the nearest base class that defines a different one, so that every level of a
-- hierarchy calls the level above it.
-- @param class_table [Map/Boolean the class, or false above the topmost class]
-- @param obj [Map the object being created]
-- @param ... [Vararg arguments of the constructor]
local function call_init(class_table, obj, ...)
  if !istable(class_table) then return end

  local base_class = class_table.parent

  while istable(base_class) and (!isfunction(class_table.init) or class_table.init == base_class.init) do
    class_table = base_class
    base_class = class_table.parent
  end

  local init = class_table.init

  if !isfunction(init) then return end

  local old_super = super

  super = function(...)
    return call_init(base_class, obj, ...)
  end

  init(obj, ...)

  super = old_super
end

--- Creates a new class. Supports constructors and inheritance.
-- The class is stored in the global table, or inside of another table when the name is
-- namespaced with `::`; that table has to exist. Every class gets a `new` function that
-- creates an instance and calls its `init` constructor, and an `include` method that mixes a
-- module into the class. Inside of a constructor, `super(...)` calls the constructor of the
-- base class, at every level of the hierarchy.
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
-- `new` copies the fields of the class into every instance. A table stored on the class is
-- therefore one table shared by the class and all of its instances: create the tables an
-- instance owns in `init`.
--
-- Running `class` for a name that exists, as a code refresh does, replaces the class table.
-- Static state stored on the class is lost, and the instances created before keep the
-- methods and the `class` field of the replaced table.
-- @param name [String class name in ConstantStyle, may be namespaced (e.g. 'ActiveRecord::Model')]
-- @param parent_class=nil [String/Map base class or its name]
-- @return [Map the created class]
-- @see [extends]
-- @see [mod]
function class(name, parent_class)
  if parent_class != nil then
    parent_class = find_base(name, parent_class)
  end

  local path = name:split('::')

  name = table.remove(path)

  local parent = _G

  if #path > 0 then
    parent = table.concat(path, '::'):parse_table()
  end

  if !istable(parent) then
    error('cannot create class '..name..', the table it belongs in does not exist\n')
  end

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

  obj.new = function(...)
    local new_obj = {}
    local real_class = parent[name]
    local old_super = super

    setmetatable(new_obj, real_class)
    table.safe_merge(new_obj, real_class)

    local success, value = pcall(call_init, real_class, new_obj, ...)

    super = old_super

    if !success then
      ErrorNoHalt('['..name..'] Class constructor has failed to run!\n')
      error_with_traceback(value)
    end

    new_obj.class = real_class
    new_obj.static_class = false
    new_obj.IsValid = always_valid

    return new_obj
  end

  obj.include = include_module

  if istable(parent_class) then
    apply_base(obj, parent_class)
  end

  last_class = { name = name, parent = parent }

  return obj
end

--- Copies the listed methods of a class onto another object.
-- ```
-- -- Makes MyLibrary.now and MyLibrary.tomorrow point to the DateTime functions.
-- delegate(MyLibrary, { 'now', 'tomorrow', to = 'DateTime' })
-- ```
-- @param obj [Map object or class that receives the methods]
-- @param t [Map method names as array elements, the source class or its name in the `to` key]
-- @return [Boolean true, or nil if obj or t is not a table or `to` is missing]
function delegate(obj, t)
  if !istable(obj) or !istable(t) or !t.to then return end

  local class = isstring(t.to) and t.to:parse_table() or t.to

  if istable(class) and class.class_name then
    for _, method_name in ipairs(t) do
      obj[method_name] = class[method_name]
    end
  end

  return true
end

--- Sets the base class of the class that is currently being created.
-- Copies the base class into the class created by the last `class` call, then calls the
-- base class's `class_extended(new_class)` method with that class and runs the ClassExtended
-- hook. A base class that is not defined is reported with a traceback, and the class is left
-- without a base.
-- ```
-- class 'DateTime' extends 'Date'
--
-- -- The base class can also be passed as a table.
-- class 'Dog' extends(Animal)
-- ```
-- @param parent_class [String/Map base class or its name]
-- @return [Boolean whether the extension succeeded]
-- @see [class]
function extends(parent_class)
  if !istable(last_class) then return false end

  local obj = last_class.parent[last_class.name]

  parent_class = find_base(obj.class_name, parent_class)

  if !parent_class then return false end

  apply_base(obj, parent_class)

  last_class = nil

  return true
end
