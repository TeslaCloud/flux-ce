--- Installer of the Cable package: loads the library into the `Cable` global, from the full
-- source on the server and from the minified file on clients.

--- Called by the Package manager once the package has been included.
-- Sends the minified library to clients and loads Cable into the global of the same name.
function PACKAGE:__installed__()
  AddCSLuaFile(self.__path__..'lib/cable.min.lua')

  if !Cable then
    Cable = include(self.__path__..(SERVER and 'lib/cable.lua' or 'lib/cable.min.lua'))
  end
end
