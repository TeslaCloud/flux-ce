local COMMAND = Command.new('textadd')
COMMAND.name = 'TextAdd'
COMMAND.description = t'3d_text.text_add_desc'
COMMAND.syntax = t'3d_text.text_add_syntax'
COMMAND.category = 'misc'
COMMAND.arguments = 1

function COMMAND:on_run(player, text, scale, style, color, extra_color)
  if !text or text == '' then
    fl.player:notify(player, t'3d_text.not_enough_text')

    return
  end

  local trace = player:GetEyeTraceNoCursor()
  local angle = trace.HitNormal:Angle()
  angle:RotateAroundAxis(angle:Forward(), 90)
  angle:RotateAroundAxis(angle:Right(), 270)

  local data = {
    text = text,
    style = style or 0,
    color = (color and Color(color)) or Color('#FFFFFF'),
    extra_color = (extra_color and Color(extra_color)) or Color('#FF0000'),
    angle = angle,
    pos = trace.HitPos,
    normal = trace.HitNormal,
    scale = scale or 1
  }

  fl3DText:AddText(data)

  fl.player:notify(player, t'3d_text.text_added')
end

COMMAND:register()
