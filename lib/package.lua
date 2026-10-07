---
-- Package is the manager of Flux packages.
--
-- This library is the centralized controlling mechanism for them.
-- Individual packages are represented by PackageInstance objects.

AddCSLuaFile()

if Package then return end

local schema_name = engine.ActiveGamemode()
local search_paths = {
  ['flux/packages/']            = true,
  [schema_name..'/schema/lib/'] = true,
  [schema_name..'/packages/']   = true,
  ['_flux/packages/']           = true,
  ['']                          = true
}

if !Flux or (CLIENT and (!Flux or !Flux.shared or !Flux.shared.packages)) then
  require_relative 'flux/lib/flux_struct'
end

require_relative 'package_instance'

local package_metadata = {}

if SERVER then
  Flux.shared.packages = {}
else
  package_metadata = Flux.shared.packages
end

Package           = {}
Package.installed = {}
Package.current   = nil

--- Adds a search path relative to the 'LUA' system.
-- @param path [String folder to look for packages in; a trailing slash is added if missing]
-- @return [Package self]
function Package:add_path(path)
  search_paths[path:ensure_end('/')] = true
  return self
end

--- Describes the current package's specification.
-- For every singular function there is a plural alias and vice versa.
-- ```
-- Package:describe(function(s)
--   s.name        = 'Example Package'
--   s.version     = '1.0'
--   s.date        = '2019-03-09'
--   s.summary     = 'Brief summary of what the package does.'
--   s.description = 'A more detailed description of what the package does.'
--   s.authors     = { 'Flux Developer' }
--   s.email       = 'example@example.com'
--   s.files       = { 'lib/example.lua', 'config/example.lua' }
--   s.global      = 'ExamplePackage'
--   s.website     = 'https://example.com'
--   s.license     = 'MIT'
--
--   s.depends     'random_dependency'
--
--   if IS_DEVELOPMENT then
--     s.depends   'random_development_package'
--   end
-- end)
-- ```
-- @param callback=nil [Function receives the specification object to fill in as its only
--   argument]
-- @return [PackageInstance]
function Package:describe(callback)
  if callback then
    local mt = setmetatable({ depends = self.current.depends }, { __newindex = function(o, k, v)
      if k:ends('s') then
        if k:ends('ies') then
          k = k:gsub('ies$', 'y')
        else
          k = k:gsub('s$', '')
        end
      end

      self.current.metadata[k] = v
    end
    })

    callback(mt)
  end

  local meta = self.current.metadata

  if SERVER and meta.clientside then
    if istable(meta.file) then
      for k, filename in ipairs(meta.file) do
        AddCSLuaFile(filename)
      end
    elseif isstring(meta.file) then
      AddCSLuaFile(meta.file)
    end

    return self.current
  end

  if !istable(meta.global) then
    meta.global = { meta.global }
  end

  for k, v in ipairs(meta.global) do
    if isstring(v) then
      _G[v] = istable(_G[v]) and _G[v] or {}

      if !_G[v].__package__ then
        _G[v].__package__ = meta
      end
    end
  end

  -- Once globals are set-up, include dependencies!
  if istable(meta.deps) then
    for k, name in ipairs(meta.deps) do
      if name:ends('.lua') then
        include(self.current.__path__..name)
        continue
      end

      if !self:included(name) then
        self:include(name)
      end
    end
  end

  if meta.serverside then
    require_ignore('client', true)
  end

  local full_path = meta.full_path
  local client_files, server_files = meta.cl_file, meta.sv_file

  if isstring(client_files) then client_files = { client_files } end
  if isstring(server_files) then server_files = { server_files } end

  if SERVER then
    if istable(client_files) then
      for k, v in ipairs(client_files) do
        AddCSLuaFile(v)
      end
    end

    if istable(server_files) then
      for k, v in ipairs(server_files) do
        include(v)
      end
    end
  elseif istable(client_files) then
    for k, v in ipairs(client_files) do
      include(self.current.__path__..v)
    end
  end

  if istable(meta.file) then
    for k, filename in ipairs(meta.file) do
      require_relative(full_path..filename)
    end
  elseif isstring(meta.file) then
    require_relative(full_path..meta.file)
  end

  if meta.serverside then
    require_ignore('client', false)
  end

  return self.current
end

--- Determines if the package has already been installed.
-- @alias [Package.present]
-- @alias [Package.is_installed]
-- @param name [String package name]
-- @return [Boolean]
function Package:included(name)
  return istable(self.installed[name])
end

Package.present       = Package.included
Package.is_installed  = Package.included

--- Searches for a package with the specified name and returns
-- the full path to its packagespec, the name of the package and
-- the full path to the folder.
-- Returns false if the package cannot be found.
-- @param name [String package name, or path to the package's folder]
-- @return [String/Boolean packagespec path or false if not found, String name,
--   String folder path]
function Package:find(name)
  local folder_path = name:ensure_end('/')
  local files, _ = file.Find(folder_path..'packagespec.lua', 'LUA')

  if !istable(files) or #files == 0 then
    for path, v in pairs(search_paths) do
      local full_path = path..folder_path:ensure_end('/')
      local files, _ = file.Find(full_path..'packagespec.lua', 'LUA')

      if istable(files) and #files > 0 then
        return full_path..files[1], name, full_path
      end
    end
  elseif istable(files) then
    return folder_path..files[1], name, folder_path
  end

  return false
end

--- Searches for the package with the specified name and
-- returns true if the package exists, false otherwise.
-- @param name [String package name, or path to the package's folder]
-- @return [Boolean]
function Package:exists(name)
  return tobool(self:find(name))
end

--- Reloads the package with the specified name.
-- Does nothing unless the package is installed and its specification allows reloading.
-- @param name [String package name]
function Package:reload(name)
  if istable(self.installed[name]) and self.installed[name].metadata.reload then
    self.installed[name] = nil
    return self:include(name)
  end
end

--- Parse a version string.
-- ```
-- Package:parse_version('~> 1.2.3-beta')
-- -- { x = 1, y = 2, z = 3, sum = 123, suffix = 'beta', op = '~>' }
-- ```
-- @param version [String version such as '1.0', '>= 1.2.0' or '~> 1.2.3-beta']
-- @return [Map version data with the fields x, y, z, sum, suffix and op]
function Package:parse_version(version)
  local buf = nil
  local init = 1
  local last = 'x'
  local version_data = {
    x = nil,
    y = nil,
    z = nil,
    sum = nil,
    suffix = nil,
    op = '=='
  }

  version = version:gsub('%s', '')

  if version[1] == '~' or version[1] == '>' then
    version_data.op = ({ ['>']=1, ['=']=1 })[version[2]] and version:sub(1, 2) or version:sub(1, 1)
    init = version_data.op:len() + 1
  end

  for i = init, version:len() do
    local v = version[i]

    if v != '.' and v != '-' then
      buf = (buf or '')..v
    else
      if buf then
        if !version_data.x then
          version_data.x = tonumber(buf)
          last = 'y'
        elseif !version_data.y then
          version_data.y = tonumber(buf)
          last = 'z'
        elseif !version_data.z then
          version_data.z = tonumber(buf)
          last = 'suffix'
        end

        if v == '-' then last = 'suffix' end

        buf = nil
      else
        error('invalid package version: '..tostring(version)..'\n')
      end
    end
  end

  if buf then
    version_data[last] = buf
  end

  version_data.x = tonumber(version_data.x) or 0
  version_data.y = tonumber(version_data.y) or 0
  version_data.z = tonumber(version_data.z) or 0
  version_data.sum = tonumber(
    tostring(version_data.x)..
    tostring(version_data.y)..
    tostring(version_data.z)
  )

  return version_data
end

--- Returns -1 if version1 is older than version2.
-- Returns 0 if versions are equal.
-- Returns 1 if version1 is newer than version2.
-- @param version1 [Map version data from Package:parse_version]
-- @param version2 [Map version data from Package:parse_version]
-- @return [Number/Boolean -1, 0 or 1; false if either argument is not a table]
function Package:compare_version(version1, version2)
  if !istable(version1) or !istable(version2) then return false end

  local s1, s2 = version1.sum or 0, version2.sum or 0

  if s1 < s2 then
    return -1
  elseif s1 == s2 then
    return 0
  elseif s1 > s2 then
    return 1
  end
end

--- Returns true if version2 matches the version1 template.
-- @param version1 [Map version data of the template, its op field sets the comparison]
-- @param version2 [Map version data of the version to check]
-- @return [Boolean]
function Package:is_version(version1, version2)
  local res = self:compare_version(version1, version2)

  if version1.op == '==' and res == 0 then
    if version1.suffix and version1.suffix != version2.suffix then return false end

    return true
  elseif version1.op == '>=' and (res == -1 or res == 0) then
    return true
  elseif version1.op == '~>' and res != 1 then
    if res == 0 then return true end

    local x, y, z, x1, y1, z1 = version1.x, version1.y, version1.z, version2.x, version2.y, version2.z

    if x == x1 then
      if y == y1 then
        return z1 >= z
      elseif z == 0 and y == 0 then
        return true
      elseif z == 0 then
        return y1 >= y
      end
    end
  end

  return false
end

do
  --- @ignore
  local function do_include(file_path, lib_path, full_path)
    if istable(Package.installed[lib_path]) and !Package.installed[lib_path].metadata.reload then
      return
    end

    local parent_package

    if Package.current then
      parent_package = Package.current
    end

    Package.current = PackageInstance.new(file_path, lib_path, full_path)
    PACKAGE = Package.current

    if CLIENT then
      Package.current.metadata = package_metadata[lib_path]
      Package:describe()
    else
      include(file_path)

      if !Package.current.metadata.serverside then
        Flux.shared.packages[lib_path] = table.Copy(Package.current.metadata)
      else
        Flux.shared.packages[lib_path] = false
      end
    end

    Package.installed[lib_path] = Package.current

    if isfunction(Package.current.__installed__) then
      Package.current:__installed__()
    end

    Package.current = parent_package
    PACKAGE         = parent_package
  end

  --- Attempts to include the package with the specified name.
  -- This function will look for the package in the search paths that have previously been added.
  -- If no package with the matching name can be found, throws an error.
  -- @param name [String package name, or path to the package's folder]
  -- @param version=nil [String currently unused]
  -- @return [Boolean true if name is a .lua file, which is skipped; nothing otherwise]
  function Package:include(name, version)
    -- Skip Lua files.
    if name:EndsWith('.lua') then return true end

    if SERVER then
      local folder_path = name:ensure_end('/')
      local files, _ = file.Find(folder_path..'packagespec.lua', 'LUA')

      if !istable(files) or #files == 0 then
        for path, v in pairs(search_paths) do
          local full_path = path..folder_path:ensure_end('/')
          local files, _ = file.Find(full_path..'packagespec.lua', 'LUA')

          if istable(files) and #files > 0 then
            return do_include(full_path..files[1], name, full_path)
          end
        end

        error('could not load "'..name..'" (no package spec file found)')
      elseif istable(files) and #files > 0 then
        return do_include(folder_path..files[1], name, folder_path)
      else
        error('could not load "'..name..'" (library not found)')
      end
    else
      local meta = package_metadata[name]

      if meta == false then return end

      return do_include(meta.file_path, name, meta.full_path)
    end
  end
end
