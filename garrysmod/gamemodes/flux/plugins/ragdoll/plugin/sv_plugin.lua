local player_meta = FindMetaTable('Player')

player_meta.old_get_ragdoll = player_meta.old_get_ragdoll or player_meta.get_ragdoll_entity

function player_meta:get_ragdoll_entity()
  return self:GetDTEntity(ENT_RAGDOLL)
end

function player_meta:set_ragdoll_entity(entity)
  self:SetDTEntity(ENT_RAGDOLL, entity)
end

function player_meta:is_ragdolled()
  local rag_state = self:GetDTInt(INT_RAGDOLL_STATE)

  if rag_state and rag_state != RAGDOLL_NONE then
    return true
  end

  return false
end

function player_meta:find_best_position(margin, filter)
  margin = margin or 3

  local pos = self:GetPos()
  local min, max = Vector(-16, -16, 0), Vector(16, 16, 32)
  local positions = {}

  for x = -margin, margin do
    for y = -margin, margin do
      local pick = pos + Vector(x * margin * 10, y * margin * 10, 0)

      if !util.IsInWorld(pick) then continue end

      local data = {}
        data.start = pick + min + Vector(0, 0, margin * 1.25)
        data.endpos = pick + max
        data.filter = filter or self
      local trace = util.TraceLine(data)

      if trace.StartSolid or trace.Hit then continue end

      data.start = pick + Vector(-max.x, -max.y, margin * 1.25)
      data.endpos = pick + Vector(min.x, min.y, 32)

      local trace2 = util.TraceLine(data)

      if trace2.StartSolid or trace2.Hit then continue end

      data.start = pos
      data.endpos = pick

      local trace3 = util.TraceLine(data)

      if trace3.Hit then continue end

      table.insert(positions, pick)
    end
  end

  table.sort(positions, function(a, b)
    return a:Distance(pos) < b:Distance(pos)
  end)

  return positions
end

function player_meta:create_ragdoll_entity(decay, fallen)
  if !IsValid(self:GetDTEntity(ENT_RAGDOLL)) then
    local ragdoll = ents.Create('prop_ragdoll')
      ragdoll:SetModel(self:GetModel())
      ragdoll:SetPos(self:GetPos())
      ragdoll:SetAngles(self:GetAngles())
      ragdoll:SetSkin(self:get_skin())
      ragdoll:SetMaterial(self:GetMaterial())
      ragdoll:SetColor(self:GetColor())
      ragdoll.decay = decay
      ragdoll.weapons = {}
    ragdoll:Spawn()

    if fallen then
      ragdoll:CallOnRemove('getup', function()
        if IsValid(self) then
          self:SetPos(ragdoll:GetPos())

          self:reset_ragdoll_entity()

          if ragdoll.weapons then
            for k, v in ipairs(ragdoll.weapons) do
              self:Give(v)
            end
          end

          self:GodDisable()
          self:Freeze(false)
          self:SetNoDraw(false)
          self:SetNotSolid(false)

          if self:is_stuck() then
            self:DropToFloor()
            self:SetPos(self:GetPos() + Vector(0, 0, 16))

            if !self:is_stuck() then return end

            local positions = self:find_best_position(4, {ragdoll, self})

            for k, v in ipairs(positions) do
              self:SetPos(v)

              if !self:is_stuck() then
                return
              else
                self:DropToFloor()

                if !self:is_stuck() then return end
              end
            end
          end
        end
      end)

      for k, v in ipairs(self:GetWeapons()) do
        table.insert(ragdoll.weapons, v:GetClass())
      end

      self:GodDisable()
      self:StripWeapons()
      self:Freeze(true)
      self:SetNoDraw(true)
      self:SetNotSolid(true)
    end

    if IsValid(ragdoll) then
      ragdoll:SetCollisionGroup(COLLISION_GROUP_WEAPON)

      local velocity = self:GetVelocity()

      for i = 1, ragdoll:GetPhysicsObjectCount() do
        local phys_obj = ragdoll:GetPhysicsObjectNum(i)
        local bone = ragdoll:TranslatePhysBoneToBone(i)
        local position, angle = self:GetBonePosition(bone)

        if IsValid(phys_obj) then
          phys_obj:SetPos(position)
          phys_obj:SetAngles(angle)
          phys_obj:SetVelocity(velocity)
        end
      end
    end

    self:SetDTEntity(ENT_RAGDOLL, ragdoll)
  end
end

function player_meta:reset_ragdoll_entity()
  local ragdoll = self:GetDTEntity(ENT_RAGDOLL)

  if IsValid(ragdoll) then
    if !ragdoll.decay then
      ragdoll:Remove()
    else
      timer.Simple(ragdoll.decay, function()
        if IsValid(ragdoll) then
          ragdoll:Remove()
        end
      end)
    end

    self:SetDTEntity(ENT_RAGDOLL, Entity(0))
  end
end

function player_meta:set_ragdoll_state(state)
  local state = state or RAGDOLL_NONE

  self:SetDTInt(INT_RAGDOLL_STATE, state)

  if state == RAGDOLL_FALLENOVER then
    self:set_action('fallen', true)
    self:create_ragdoll_entity(nil, true)
  elseif state == RAGDOLL_DUMMY then
    self:create_ragdoll_entity(120)
  elseif state == RAGDOLL_NONE then
    self:reset_ragdoll_entity()
  end
end
