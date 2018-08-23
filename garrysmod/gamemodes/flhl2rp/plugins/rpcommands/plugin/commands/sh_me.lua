local COMMAND = Command("me")
COMMAND.name = "Me"
COMMAND.description = "Describe your action."
COMMAND.Syntax = "<text>"
COMMAND.category = "roleplay"
COMMAND.Aliases = {"perform", "e"}
COMMAND.Arguments = 1

function COMMAND:OnRun(player, ...)
  chatbox.AddText(nil, Color("green"), player:name().." "..table.concat({...}, " "), {sender = player, position = player:GetPos(), radius = config.Get("talk_radius"), hearWhenLook = true})
end

COMMAND:register()
