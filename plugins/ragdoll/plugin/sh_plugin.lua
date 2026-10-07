require_relative 'cl_hooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'
require_relative 'sh_enums'

--- Moves the view to the eyes of the player's ragdoll while they have one and are not
-- drawn in third person.
-- @param client [Player]
-- @param origin [Vector]
-- @param angles [Angle]
-- @param fov [Number]
-- @return [Map view table, or nil if the view is left alone]
function PLUGIN:CalcView(client, origin, angles, fov)
  local view = GAMEMODE.BaseClass:CalcView(client, origin, angles, fov) or {}
  local entity = client:GetDTEntity(ENT_RAGDOLL)

  if !client:ShouldDrawLocalPlayer() and IsValid(entity) and entity:IsRagdoll() then
    local index = entity:LookupAttachment('eyes')

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

--- Registers the RagdollState and RagdollEntity data table variables on the player.
-- @param target [Player]
function PLUGIN:PlayerSetupDataTables(target)
  target:DTVar('Int', INT_RAGDOLL_STATE, 'RagdollState')
  target:DTVar('Entity', ENT_RAGDOLL, 'RagdollEntity')
end
