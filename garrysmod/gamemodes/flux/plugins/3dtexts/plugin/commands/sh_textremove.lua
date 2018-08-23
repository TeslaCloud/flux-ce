local COMMAND = Command("textremove")
COMMAND.name = "TextRemove"
COMMAND.description = "Removes a 3D text."
COMMAND.Syntax = "[none]"
COMMAND.category = "misc"

function COMMAND:OnRun(player)
  fl3DText:Remove(player)
end

COMMAND:register()
