--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

local playerMeta = FindMetaTable("Player");

playerMeta.OldGetRagdoll = playerMeta.GetRadgollEntity;

function playerMeta:GetRagdollEntity()
	return self:GetDTEntity(ENT_RAGDOLL);
end;

function playerMeta:GetRagdollEntity()
	return self:GetDTEntity(ENT_RAGDOLL);
end;

function playerMeta:SetRagdollEntity(ent)
	self:SetDTEntity(ENT_RAGDOLL, ent);
end;

function playerMeta:IsRagdolled()
	local ragState = self:GetDTInt(INT_RAGDOLL_STATE);

	if (ragState and ragState != RAGDOLL_NONE) then
		return true;
	end;

	return false;
end;

function playerMeta:CreateRagdollEntity(decay)
	if (!IsValid(self:GetDTEntity(ENT_RAGDOLL))) then
		local ragdoll = ents.Create("prop_ragdoll");
			ragdoll:SetModel(self:GetModel());
			ragdoll:SetPos(self:GetPos());
			ragdoll:SetAngles(self:GetAngles());
			ragdoll:SetSkin(self:GetSkin());
			ragdoll:SetMaterial(self:GetMaterial());
			ragdoll:SetColor(self:GetColor());
			ragdoll.decay = decay;
		ragdoll:Spawn();

		if (IsValid(ragdoll)) then
			ragdoll:SetCollisionGroup(COLLISION_GROUP_DEBRIS);

			local head = ragdoll:LookupBone("ValveBiped.Bip01_Head1");
			local velocity = self:GetVelocity();

			for i = 1, ragdoll:GetPhysicsObjectCount() do
				local physObj = ragdoll:GetPhysicsObjectNum(i);
				local bone = ragdoll:TranslatePhysBoneToBone(i);
				local position, angle = self:GetBonePosition(bone);

				if (IsValid(physObj)) then
					physObj:SetPos(position);
					physObj:SetAngles(angle);

					if (bone == head) then
						physObj:SetVelocity(velocity * 1.5);
					else
						physObj:SetVelocity(velocity);
					end;
				end;
			end;
		end;

		self:SetDTEntity(ENT_RAGDOLL, ragdoll);
	end;
end;

function playerMeta:ResetRagdollEntity()
	local ragdoll = self:GetDTEntity(ENT_RAGDOLL);

	if (IsValid(ragdoll)) then
		if (!ragdoll.decay) then
			ragdoll:Remove();
		else
			timer.Simple(ragdoll.decay, function()
				ragdoll:Remove();
			end);
		end;

		self:SetDTEntity(ENT_RAGDOLL, Entity(0));
	end;
end;

function playerMeta:SetRagdollState(state)
	local state = state or RAGDOLL_NONE;

	self:SetDTInt(INT_RAGDOLL_STATE, state);

	if (state == RAGDOLL_FALLENOVER) then
		self:CreateRagdollEntity();
	elseif (state == RAGDOLL_DUMMY) then
		self:CreateRagdollEntity(120);
	elseif (state == RAGDOLL_NONE) then
		self:ResetRagdollEntity();
	end;
end;