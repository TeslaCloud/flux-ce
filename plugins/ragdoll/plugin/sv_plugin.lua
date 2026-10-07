local player_meta = FindMetaTable('Player')

player_meta.old_get_ragdoll = player_meta.old_get_ragdoll or player_meta.get_ragdoll_entity

--- Returns the player's ragdoll entity. Serverside only.
-- @return [Entity the ragdoll, or a NULL entity if the player has none]
function player_meta:get_ragdoll_entity()
  return self:GetDTEntity(ENT_RAGDOLL)
end

--- Sets the networked ragdoll entity of the player. Does not spawn or remove anything.
-- Serverside only.
-- @param entity [Entity]
function player_meta:set_ragdoll_entity(entity)
  self:SetDTEntity(ENT_RAGDOLL, entity)
end

--- Checks whether the player is in any ragdoll state other than RAGDOLL_NONE.
-- Serverside only.
-- @return [Boolean]
function player_meta:is_ragdolled()
  local rag_state = self:GetDTInt(INT_RAGDOLL_STATE)

  if rag_state and rag_state != RAGDOLL_NONE then
    return true
  end

  return false
end

--- Spawns a ragdoll copy of the player and stores it as their ragdoll entity. Does nothing
-- if they already have a valid one. A fallen player is frozen, hidden and stripped of
-- their weapons; once the ragdoll is removed they are moved to it and get them back.
-- Serverside only.
-- @param decay=nil [Number seconds the ragdoll remains after the ragdoll entity is reset;
--   nil removes it right away]
-- @param fallen=false [Boolean whether the player has fallen over rather than died]
-- @see [Player#set_ragdoll_state]
function player_meta:create_ragdoll_entity(decay, fallen)
  if !IsValid(self:GetDTEntity(ENT_RAGDOLL)) then
    local ragdoll = ents.Create('prop_ragdoll')
      ragdoll:SetModel(self:GetModel())
      ragdoll:SetPos(self:GetPos())
      ragdoll:SetAngles(self:GetAngles())
      ragdoll:SetSkin(self:GetSkin())
      ragdoll:SetMaterial(self:GetMaterial())
      ragdoll:SetColor(self:GetColor())
      ragdoll.player = self
      ragdoll.decay = decay
      ragdoll.weapons = {}
    ragdoll:Spawn()

    if fallen then
      ragdoll:CallOnRemove('getup', function()
        if IsValid(self) then
          self:SetPos(ragdoll:GetPos())

          self:reset_ragdoll_entity()

          if ragdoll.weapons then
            self:give_weapons(ragdoll.weapons)
          end

          self:GodDisable()
          self:Freeze(false)
          self:SetNoDraw(false)
          self:SetNotSolid(false)

          if self:stuck() then
            self:DropToFloor()
            self:SetPos(self:GetPos() + Vector(0, 0, 16))

            if !self:stuck() then return end

            self:unstuck({ ragdoll, self })
          end
        end
      end)

      ragdoll.weapons = self:get_weapons_list()

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

--- Detaches the player's ragdoll and removes it, right away or after its decay time.
-- Does nothing if the player has no valid ragdoll. Serverside only.
function player_meta:reset_ragdoll_entity()
  local ragdoll = self:GetDTEntity(ENT_RAGDOLL)

  if IsValid(ragdoll) then
    ragdoll.player = nil

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

--- Sets the player's ragdoll state and creates or removes their ragdoll to match it.
-- RAGDOLL_FALLENOVER also starts the 'fallen' action. Serverside only.
-- ```
-- target:set_ragdoll_state(RAGDOLL_FALLENOVER) -- fall over
-- target:set_ragdoll_state(RAGDOLL_NONE) -- get back up
-- ```
-- @param state=RAGDOLL_NONE [Number one of the RAGDOLL_ enums]
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
