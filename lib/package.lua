---
-- Package is the manager of Flux packages.
--
-- This library is the centralized controlling mechanism for them.
-- Individual packages are represented by PackageInstance objects.
--
-- Packages are looked up in an ordered list of search paths: the `packages` folder of the
-- project (the schema's gamemode folder), then `_flux/packages/`. A package that has a
-- `packages` folder of its own, such as a development checkout of Flux, appends it to the list
-- when it is included, so top-level packages win over nested ones. Clients find packages
-- through the metadata the server sends them. The server registers the migrations of every
-- package it includes (see `Package:add_migrations`).

AddCSLuaFile()

if Package then return end

local search_paths = {
  engine.ActiveGamemode()..'/packages/',
  '_flux/packages/'
}

if !Flux or (CLIENT and (!Flux.shared or !Flux.shared.packages)) then
  require_relative(FLUX_PATH..'lib/flux_struct')
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

--- Appends a search path relative to the 'LUA' system, after the ones already listed. A path
-- that is listed already is ignored.
-- @param path [String folder to look for packages in; a trailing slash is added if missing]
-- @return [Package self]
function Package:add_path(path)
  path = path:ensure_end('/')

  if !table.HasValue(search_paths, path) then
    search_paths[#search_paths + 1] = path
  end

  return self
end

--- Describes the current package's specification.
-- A field may be given in its plural form, such as `authors` or `files`, and is stored under
-- the singular one. Once the globals are set up, the dependencies are included, unless the
-- specification is only being read (see `Package:read`). A package without a `global`, such
-- as the project manifest of a schema, creates none. The version requirement of a dependency
-- (`'~> 0.9'` below) is checked by fpkg when it installs the packages; at runtime only the
-- name counts.
-- ```
-- Package:describe(function(s)
--   s.name        = 'Example Package'
--   s.version     = '1.0.0'
--   s.date        = '2026-11-17'
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
--   s.depends('flux', '~> 0.9')
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
    local mt = setmetatable({ depends = self.current.depends }, { __newindex = function(_o, k, v)
      if k:end_with('s') then
        if k:end_with('ies') then
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
      for _, filename in ipairs(meta.file) do
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

  for _, global_name in ipairs(meta.global) do
    if isstring(global_name) and global_name != '' then
      _G[global_name] = istable(_G[global_name]) and _G[global_name] or {}

      if !_G[global_name].__package__ then
        _G[global_name].__package__ = meta
      end
    end
  end

  if self.current.read_only then
    return self.current
  end

  self:include_dependencies(self.current)

  if meta.serverside then
    require_ignore('client', true)
  end

  local full_path = meta.full_path
  local client_files, server_files = meta.cl_file, meta.sv_file

  if isstring(client_files) then client_files = { client_files } end
  if isstring(server_files) then server_files = { server_files } end

  if SERVER then
    if istable(client_files) then
      for _, file_name in ipairs(client_files) do
        AddCSLuaFile(file_name)
      end
    end

    if istable(server_files) then
      for _, file_name in ipairs(server_files) do
        include(file_name)
      end
    end
  elseif istable(client_files) then
    for _, file_name in ipairs(client_files) do
      include(self.current.__path__..file_name)
    end
  end

  if istable(meta.file) then
    for _, filename in ipairs(meta.file) do
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

--- Includes the dependencies of a package in the order its specification lists them: the
-- packages that are not included yet and the .lua files of the package itself. Given `last`,
-- stops once that dependency is in.
-- ```
-- Package:include_dependencies(Package:read('flux'), 'active_record')
-- ```
-- @param instance [PackageInstance package whose dependencies to include]
-- @param last=nil [String name of the last dependency to include]
function Package:include_dependencies(instance, last)
  local deps = instance.metadata.deps

  if !istable(deps) then return end

  for _, name in ipairs(deps) do
    if name:end_with('.lua') then
      include(instance.__path__..name)
    elseif !self:included(name) then
      self:include(name)
    end

    if name == last then return end
  end
end

--- Registers the migrations a package ships in its `migrations` folder with the 'migrations'
-- pipeline, which installs them into the schema's `db/migrate` folder (see
-- `ActiveRecord::MigrationContext`). The server registers the folder of every package it
-- includes, once the package is in, and fpkg's tasks those of the packages of the project in
-- the same order. Does nothing before ActiveRecord is loaded or for a package without the
-- folder.
-- @realm [server]
-- @param path [String folder of the package, with a trailing slash]
function Package:add_migrations(path)
  if Pipeline then
    Pipeline.include_folder('migrations', path..'migrations/')
  end
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
-- The search paths are tried in order, the name as a path to the package's folder last, so
-- `Package:find('hl2rp')` finds the project manifest `hl2rp/packagespec.lua`.
-- Returns false if the package cannot be found.
-- @param name [String package name, or path to the package's folder]
-- @return [String/Boolean packagespec path or false if not found, String name,
--   String folder path]
function Package:find(name)
  local folder_path = name:ensure_end('/')

  for _, path in ipairs(search_paths) do
    local full_path = path..folder_path

    if file.Exists(full_path..'packagespec.lua', 'LUA') then
      return full_path..'packagespec.lua', name, full_path
    end
  end

  if file.Exists(folder_path..'packagespec.lua', 'LUA') then
    return folder_path..'packagespec.lua', name, folder_path
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
    self:include(name)
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
    version_data.op = ({ ['>'] = 1, ['='] = 1 })[version[2]] and version:sub(1, 2) or version:sub(1, 1)
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
  local including = {}

  local function load_package(file_path, lib_path, full_path)
    Package.current = PackageInstance.new(file_path, lib_path, full_path)
    PACKAGE = Package.current

    if CLIENT then
      Package.current.metadata = package_metadata[lib_path]
      Package:describe()
    else
      include(file_path)
      Package:add_migrations(full_path)

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
  end

  --- Includes the specification of a package and runs its `__installed__`, with the package as
  -- `Package.current` and `PACKAGE`, which point back to the package that depends on it once it
  -- is done, also when it fails. Throws an error for a package that depends on itself through
  -- its chain of dependencies.
  -- @param file_path [String path to the package's packagespec.lua]
  -- @param lib_path [String name of the package]
  -- @param full_path [String path to the package's folder]
  local function do_include(file_path, lib_path, full_path)
    if istable(Package.installed[lib_path]) and !Package.installed[lib_path].metadata.reload then
      return
    end

    local cycle_start = table.KeyFromValue(including, lib_path)

    if cycle_start then
      error('Cyclic package dependency: '..table.concat(including, ' -> ', cycle_start)..' -> '..lib_path, 0)
    end

    local parent_package = Package.current

    including[#including + 1] = lib_path

    local success, err = pcall(load_package, file_path, lib_path, full_path)

    including[#including] = nil
    Package.current = parent_package
    PACKAGE         = parent_package

    if !success then
      error(err, 0)
    end
  end

  --- Finds a package on the server and appends a `packages` folder inside it to the search
  -- paths. Throws an error that names the package depending on it and the folders searched if
  -- there is no such package.
  -- @param name [String package name, or path to the package's folder]
  -- @return [String path to the package's packagespec.lua, String path to its folder]
  local function locate(name)
    local spec_path, _, full_path = Package:find(name)

    if !spec_path then
      local folders = {}

      for index, path in ipairs(search_paths) do
        folders[index] = path..name..'/'
      end

      folders[#folders + 1] = name:ensure_end('/')

      local project = engine.ActiveGamemode()
      local dependent = Package.current ? ', a dependency of "'..Package.current.metadata.lib_path..'"' : ''

      error('could not load "'..name..'"'..dependent..': no packagespec.lua in '..table.concat(folders, ', ')
        ..'\nRun "fpkg install" in gamemodes/'..project
        ..', or "fpkg link <checkout>" for a development checkout.', 0)
    end

    if file.IsDir(full_path..'packages', 'LUA') then
      Package:add_path(full_path..'packages/')
    end

    return spec_path, full_path
  end

  --- Attempts to include the package with the specified name.
  -- On the server the package is looked up with `Package:find`; a `packages` folder inside it
  -- is appended to the search paths before its specification runs. On the client the
  -- metadata the server sent is used. If no package with the matching name can be found,
  -- throws an error that names the package depending on it and the folders searched.
  -- @param name [String package name, or path to the package's folder]
  -- @param _version=nil [String version requirement, checked by fpkg at install time and
  --   ignored here]
  -- @return [Boolean true if name is a .lua file, which is skipped; nothing otherwise]
  -- @see [Package:find]
  function Package:include(name, _version)
    if name:EndsWith('.lua') then return true end

    if SERVER then
      local spec_path, full_path = locate(name)

      return do_include(spec_path, name, full_path)
    else
      local meta = package_metadata[name]

      if meta == false then return end

      return do_include(meta.file_path, name, meta.full_path)
    end
  end

  --- Reads the specification of a package without including the package: its packagespec.lua
  -- runs and creates the globals it names, but none of its dependencies and files are
  -- included, its `__installed__` is not run and it does not count as included. A `packages`
  -- folder inside it is appended to the search paths, as `Package:include` does. fpkg's tasks
  -- read the `flux` package this way, which gives `Flux.get_version` its version.
  -- @realm [server]
  -- @param name [String package name, or path to the package's folder]
  -- @return [PackageInstance the package, with its metadata filled in]
  function Package:read(name)
    local spec_path, full_path = locate(name)
    local parent_package = self.current
    local instance = PackageInstance.new(spec_path, name, full_path)

    instance.read_only = true
    self.current = instance
    PACKAGE = instance

    include(spec_path)

    self.current = parent_package
    PACKAGE = parent_package

    return instance
  end
end
