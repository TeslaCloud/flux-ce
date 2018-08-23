local ent_meta = FindMetaTable("Entity")

--[[
  We store the original function here so we can override it from the player metaTable,
  which derives from the entity metaTable. This way we don't have to check if the entity is
  player every time the function is called.
--]]
ent_meta.flSetModel = ent_meta.flSetModel or ent_meta.SetModel

function ent_meta:IsStuck()
  local pos = self:GetPos()

  local trace = util.TraceHull({
    start = pos,
    endpos = pos,
    filter = self,
    mins = self:OBBMins(),
    maxs = self:OBBMaxs()
  })

  return trace.Entity and (trace.Entity:IsWorld() or trace.Entity:IsValid())
end
