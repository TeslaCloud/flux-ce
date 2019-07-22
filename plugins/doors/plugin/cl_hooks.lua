function PLUGIN:PostDrawTranslucentRenderables(depth, skybox)
  if depth or skybox then return end

  local eye_pos = EyePos()

  for k, v in ipairs(ents.FindInSphere(eye_pos, 256)) do
    if IsValid(v) and v:is_door() then
      local title = v:get_nv('fl_title_type')
      local title_data = Doors.title_types[title]

      if !title or title == '' or !title_data or !title_data.draw then
        continue
      end

      local ang, pos = v:GetAngles(), v:LocalToWorld(v:OBBCenter())
      local mins, maxs = v:OBBMins(), v:OBBMaxs()
      local size = maxs - mins
      local alpha = 255 * (1 - (eye_pos:Distance(pos) / 256))
      local ang_offset, pos_offset
      local w, h

      if size.x < size.y and size.x < size.z then
        ang_offset = Angle(0, 90, 90)
        pos_offset = v:GetForward() * size.x * 0.5

        w = size.y
        h = size.z
      elseif size.y < size.z then
        ang_offset = Angle(0, 0, 90)
        pos_offset = v:GetRight() * size.y * 0.5

        w = size.x
        h = size.z
      elseif size.z < size.y then
        ang_offset = Angle(90, 90, 0)
        pos_offset = v:GetUp() * size.z * 0.5

        w = size.x
        h = size.y
      end

      ang:Add(ang_offset)

      local trace = util.TraceLine({
        start = pos + pos_offset,
        endpos = pos,
        collisiongroup = COLLISION_GROUP_WORLD,
        ignoreworld = true
      })

      local mult = 0.05

      if trace.HitNormal:Dot((eye_pos - pos):GetNormalized()) > 0 then
        cam.Start3D2D(trace.HitPos + pos_offset * 0.05, ang, mult)
          title_data.draw(v, w / mult, h / mult, alpha)
        cam.End3D2D()
      else
        cam.Start3D2D(pos + (pos - trace.HitPos) * 1.05, ang + Angle(0, 180, 0), mult)
          if title_data.draw_back then
            title_data.draw_back(v, w / mult, h / mult, alpha)
          else
            title_data.draw(v, w / mult, h / mult, alpha)
          end
        cam.End3D2D()
      end
    end
  end
end
