--- Client side of the 3D Texts plugin: finding the text or picture that a trace hits and
-- asking the server to remove it.

local abs = math.abs
local cable_send = Cable.send

--- Finds the 3D text hit by the trace and asks the server to remove it. Clientside only.
-- @param trace [Map trace result, e.g. from Player:GetEyeTraceNoCursor]
-- @return [Boolean true if a text was hit and its removal was requested]
function SurfaceText:trace_remove_text(trace)
  if !trace then return false end

  local hit_pos = trace.HitPos - trace.HitNormal
  local hit_z = abs(hit_pos.z)
  local trace_start = trace.StartPos
  local font = Theme.get_font('text_3d2d')

  for text_id, text_data in pairs(self.texts) do
    local pos = text_data.pos
    local normal = text_data.normal
    local ang = normal:Angle()
    local w, _h = util.text_size(text_data.text, font)
    local scale = text_data.scale
    local offset = -ang:Right() * (w * 0.05) * scale
    local start_pos = pos - offset
    local end_pos = pos + offset

    if abs(hit_z - abs(pos.z)) < 4 * scale then
      if util.vectors_intersect(trace_start, hit_pos, start_pos, end_pos) then
        cable_send('fl_surface_text_remove', text_id)

        return true
      end
    end
  end

  return false
end

--- Finds the 3D picture hit by the trace and asks the server to remove it. Clientside only.
-- @param trace [Map trace result, e.g. from Player:GetEyeTraceNoCursor]
-- @return [Boolean true if a picture was hit and its removal was requested]
function SurfaceText:trace_remove_picture(trace)
  if !trace then return false end

  local hit_pos = trace.HitPos - trace.HitNormal
  local hit_z = abs(hit_pos.z)
  local trace_start = trace.StartPos

  for picture_id, picture in pairs(self.pictures) do
    local pos = picture.pos
    local normal = picture.normal
    local ang = normal:Angle()
    local width, height = picture.width, picture.height
    local offset = -ang:Right() * (width * 0.05)
    local start_pos = pos - offset
    local end_pos = pos + offset

    if abs(hit_z - abs(pos.z)) < height * 0.05 then
      if util.vectors_intersect(trace_start, hit_pos, start_pos, end_pos) then
        cable_send('fl_surface_picture_remove', picture_id)

        return true
      end
    end
  end

  return false
end
