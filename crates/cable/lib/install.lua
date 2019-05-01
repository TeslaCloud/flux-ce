function CRATE:__installed__()
  AddCSLuaFile(self.__path__..'lib/cable.min.lua')

  if !Cable then
    Cable = include(self.__path__..(SERVER and 'lib/cable.lua' or 'lib/cable.min.lua'))
  end
end
