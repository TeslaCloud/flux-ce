--- Installer of the Cable package: sends the library to clients and loads it into the `Cable`
-- global on both realms.

--- Called by the Package manager once the package has been included.
function PACKAGE:__installed__()
  AddCSLuaFile(self.__path__..'lib/cable.lua')

  if !Cable then
    Cable = include(self.__path__..'lib/cable.lua')
  end
end
