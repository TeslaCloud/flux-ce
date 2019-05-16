--- A Flux package (also referred to as "Crate") instance class.
-- This provides basic information fields and dependencies.
class 'Package'

--- Class constructor. Takes file path, file name and folder path as the arguments.
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
function Package:depends(what)
  local name = isstring(self) and self or what

  if istable(self) then
    table.insert(self.metadata.deps, name)
  else
    table.insert(CRATE.metadata.deps, name)
  end
end
