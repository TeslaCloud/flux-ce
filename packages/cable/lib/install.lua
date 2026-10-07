--- Called by the Package manager once the package has been included.
-- Sends the minified library to clients and loads Cable into the global of the same name.
function PACKAGE:__installed__()
  AddCSLuaFile(self.__path__..'lib/cable.min.lua')

  if !Cable then
    Cable = include(self.__path__..(SERVER and 'lib/cable.lua' or 'lib/cable.min.lua'))
  end
end
