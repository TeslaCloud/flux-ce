--- Installer of the LLM package: loads the client library into the `LLM` global. The package is
-- only included on the server, so API keys never reach the clients.

--- Called by the Package manager once the package has been included.
function PACKAGE:__installed__()
  if !LLM then
    LLM = include(self.__path__..'lib/llm.lua')
  end
end
