local player_meta = FindMetaTable('Player')

player_meta.OldGetRagdoll = player_meta.OldGetRagdoll or player_meta.GetRagdollEntity

function player_meta:GetRagdollEntity()
  return self:GetDTEntity(ENT_RAGDOLL)
end

function player_meta:SetRagdollEntity(ent)
  self:SetDTEntity(ENT_RAGDOLL, ent)
end

function player_meta:IsRagdolled()
  local ragState = self:GetDTInt(INT_RAGDOLL_STATE)

  if ragState and ragState != RAGDOLL_NONE then
    return true
  end

  return false
end

function player_meta:FindBestPosition(margin, filter)
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

function player_meta:CreateRagdollEntity(decay, fallen)
  if !IsValid(self:GetDTEntity(ENT_RAGDOLL)) then
    local ragdoll = ents.Create('prop_ragdoll')
      ragdoll:SetModel(self:GetModel())
      ragdoll:SetPos(self:GetPos())
      ragdoll:SetAngles(self:GetAngles())
      ragdoll:SetSkin(self:GetSkin())
      ragdoll:SetMaterial(self:GetMaterial())
      ragdoll:SetColor(self:GetColor())
      ragdoll.decay = decay
      ragdoll.weapons = {}
    ragdoll:Spawn()

    if fallen then
      ragdoll:CallOnRemove('getup', function()
        if IsValid(self) then
          self:SetPos(ragdoll:GetPos())

          self:ResetRagdollEntity()

          if ragdoll.weapons then
            for k, v in ipairs(ragdoll.weapons) do
              self:Give(v)
            end
          end

          self:GodDisable()
          self:Freeze(false)
          self:SetNoDraw(false)
          self:SetNotSolid(false)

          if self:IsStuck() then
            self:DropToFloor()
            self:SetPos(self:GetPos() + Vector(0, 0, 16))

            if !self:IsStuck() then return end

            local positions = self:FindBestPosition(4, {ragdoll, self})

            for k, v in ipairs(positions) do
              self:SetPos(v)

              if !self:IsStuck() then
                return
              else
                self:DropToFloor()

                if !self:IsStuck() then return end
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
        local physObj = ragdoll:GetPhysicsObjectNum(i)
        local bone = ragdoll:TranslatePhysBoneToBone(i)
        local position, angle = self:GetBonePosition(bone)

        if IsValid(physObj) then
          physObj:SetPos(position)
          physObj:SetAngles(angle)
          physObj:SetVelocity(velocity)
        end
      end
    end

    self:SetDTEntity(ENT_RAGDOLL, ragdoll)
  end
end

function player_meta:ResetRagdollEntity()
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

function player_meta:SetRagdollState(state)
  local state = state or RAGDOLL_NONE

  self:SetDTInt(INT_RAGDOLL_STATE, state)

  if state == RAGDOLL_FALLENOVER then
    self:SetAction('fallen', true)
    self:CreateRagdollEntity(nil, true)
  elseif state == RAGDOLL_DUMMY then
    self:CreateRagdollEntity(120)
  elseif state == RAGDOLL_NONE then
    self:ResetRagdollEntity()
  end
end
