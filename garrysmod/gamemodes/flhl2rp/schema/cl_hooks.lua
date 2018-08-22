--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]function Schema:HUDPaint()
  fl.EnableColorModify()
  fl.SetColorModifyVal("color", 0.85)
  fl.SetColorModifyVal("addb", 0.015)

  surface.SetDrawColor(255, 255, 255, 255)
  surface.SetMaterial(util.GetMaterial("materials/flux/hl2rp/vignette.png"))
  surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
end
