local COMMAND = Command("textremove")
COMMAND.Name = "TextRemove"
COMMAND.Description = "Removes a 3D text."
COMMAND.Syntax = "[none]"
COMMAND.Category = "misc"

function COMMAND:OnRun(player)
  fl3DText:Remove(player)
end

COMMAND:Register()
