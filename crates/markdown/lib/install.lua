function CRATE:__installed__()
  AddCSLuaFile(self.__path__..'lib/markdown.min.lua')

  if !Markdown then
    Markdown = include(self.__path__..(SERVER and 'lib/markdown.lua' or 'lib/markdown.min.lua'))
  end
end
