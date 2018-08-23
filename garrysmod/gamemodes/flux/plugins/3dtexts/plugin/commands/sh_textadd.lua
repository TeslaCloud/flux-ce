local COMMAND = Command("textadd")
COMMAND.name = "TextAdd"
COMMAND.description = "#3DText_TextAddDesc"
COMMAND.syntax = "#3DText_TextAddSyntax"
COMMAND.category = "misc"
COMMAND.arguments = 1

function COMMAND:OnRun(player, text, scale, style, color, extraColor)
  if (!text or text == "") then
    fl.player:Notify(player, "#3DText_NotEnoughText")

    return
  end

  local trace = player:GetEyeTraceNoCursor()
  local angle = trace.HitNormal:Angle()
  angle:RotateAroundAxis(angle:Forward(), 90)
  angle:RotateAroundAxis(angle:Right(), 270)

  local data = {
    text = text,
    style = style or 0,
    color = (color and Color(color)) or Color("#FFFFFF"),
    extraColor = (extraColor and Color(extraColor)) or Color("#FF0000"),
    angle = angle,
    pos = trace.HitPos,
    normal = trace.HitNormal,
    scale = scale or 1
  }

  fl3DText:AddText(data)

  fl.player:Notify(player, "#3DText_TextAdded")
end

COMMAND:register()
