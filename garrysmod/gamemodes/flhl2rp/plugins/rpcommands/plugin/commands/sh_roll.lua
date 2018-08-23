local COMMAND = Command("roll")
COMMAND.name = "Roll"
COMMAND.description = "Roll a random number between 1 and 100 or specific number."
COMMAND.Syntax = "[number Range]"
COMMAND.category = "roleplay"
COMMAND.Arguments = 0

function COMMAND:OnRun(player, range)
  range = tonumber(range) or 100

  chatbox.AddText(nil, Color("purple"), L("Chat_Roll", player:name(), math.random(1, range), range), {sender = player, position = player:GetPos(), radius = config.Get("talk_radius"), hearWhenLook = true})
end

COMMAND:register()
