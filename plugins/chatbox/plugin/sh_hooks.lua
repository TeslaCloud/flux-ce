--- Shared hooks of the Chatbox plugin: keeps the texts that start with a chat prefix from being
-- treated as commands.

--- Keeps a text that starts with a registered chat prefix (see `Chatbox.add_prefix`) from being
-- treated as a command.
-- @param text [String the text being checked]
-- @return [Boolean false if the text starts with a chat prefix, nil otherwise]
function Chatbox:ShouldTreatAsCommand(text)
  if Chatbox.find_prefix(text) then
    return false
  end
end
