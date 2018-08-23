local COMMAND = Command("it")
COMMAND.name = "It"
COMMAND.description = "Describe something."
COMMAND.Syntax = "<text>"
COMMAND.category = "roleplay"
COMMAND.Aliases = {"do"}
COMMAND.Arguments = 1

function COMMAND:OnRun(player, ...)
  chatbox.AddText(nil, Color("lightblue"), "("..player:Name()..") "..table.concat({...}, " "), {sender = player, position = player:GetPos(), radius = config.Get("talk_radius"), hearWhenLook = true})
end

COMMAND:register()
