util.include("cl_hooks.lua")
util.include("sv_plugin.lua")
util.include("sv_hooks.lua")
util.include("sh_enums.lua")

function PLUGIN:PlayerSetupDataTables(player)
  player:DTVar("Int", INT_RAGDOLL_STATE, "RagdollState")
  player:DTVar("Entity", ENT_RAGDOLL, "RagdollEntity")
end

function PLUGIN:CalcView(player, origin, angles, fov)
  local view = GAMEMODE.BaseClass:CalcView(player, origin, angles, fov) or {}
  local entity = player:GetDTEntity(ENT_RAGDOLL)

  if !player:ShouldDrawLocalPlayer() and IsValid(entity) and entity:IsRagdoll() then
    local index = entity:LookupAttachment("eyes")

    if index then
      local data = entity:GetAttachment(index)

      if data then
        view.origin = data.Pos
        view.angles = data.Ang
      end

      return view
    end
  end
end
