local COMMAND = Command("it")
COMMAND.Name = "It"
COMMAND.Description = "Describe something."
COMMAND.Syntax = "<text>"
COMMAND.Category = "roleplay"
COMMAND.Aliases = {"do"}
COMMAND.Arguments = 1

function COMMAND:OnRun(player, ...)
  chatbox.AddText(nil, Color("lightblue"), "("..player:Name()..") "..table.concat({...}, " "), {sender = player, position = player:GetPos(), radius = config.Get("talk_radius"), hearWhenLook = true})
end

COMMAND:Register()
