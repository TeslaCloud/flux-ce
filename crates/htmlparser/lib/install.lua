function CRATE:__installed__()
  AddCSLuaFile(self.__path__..'lib/htmlparser.lua')
  AddCSLuaFile(self.__path__..'lib/htmlparser/element_node.lua')
  AddCSLuaFile(self.__path__..'lib/htmlparser/voidelements.lua')

  if !HTMLParser then
    HTMLParser = include(self.__path__..'lib/htmlparser.lua')
  end
end
