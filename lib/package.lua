--- A Flux package (also referred to as "Crate") instance class.
-- This provides basic information fields and dependencies.
class 'Package'

--- Class constructor. Takes the file path, file name and folder path as the arguments.
-- @param file_path [String path to the package's cratespec.lua]
-- @param lib_path [String name of the package, as it was given to Crate:include]
-- @param full_path [String path to the package's folder, with a trailing slash]
function Package:init(file_path, lib_path, full_path)
  self.metadata = {
    name        = '',
    version     = '',
    date        = '',
    summary     = '',
    description = '',
    author      = '',
    email       = '',
    file        = { },
    cl_file     = { },
    sv_file     = { },
    website     = '',
    license     = '',
    global      = '',
    deps        = { },
    serverside  = false,
    clientside  = false,
    reload      = true
  }

  self.metadata.file_path = file_path
  self.metadata.lib_path  = lib_path
  self.metadata.full_path = full_path
  self.__path__           = full_path
end

--- Specifies that a package is dependant on another package or plugin.
-- Merely adds to the dependency list. Can be called with either : or .
-- When called with a dot, the dependency is added to the package that is currently
-- being included (the CRATE global).
-- ```
-- Crate:describe(function(s)
--   s.depends 'pon'
--   s.depends 'lib/flux.lua'
-- end)
-- ```
-- @param what [String name of a package, or path to a .lua file inside this package]
function Package:depends(what)
  local name = isstring(self) and self or what

  if istable(self) then
    table.insert(self.metadata.deps, name)
  else
    table.insert(CRATE.metadata.deps, name)
  end
end
