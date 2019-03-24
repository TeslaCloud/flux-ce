PLUGIN:set_name 'Shared Flashlight'
PLUGIN:set_author 'TeslaCloud Studios'
PLUGIN:set_description "Makes other player's flashlight lights visible to you."

local flashlight_cutoff = 780 ^ 2

function PLUGIN:Think()
  if !IsValid(PLAYER) or !PLAYER:has_initialized() then return end

  local my_pos = PLAYER:GetPos()
  local cur_time = CurTime()

  for k, v in ipairs(player.all()) do
    if my_pos:DistToSqr(v:GetPos()) < flashlight_cutoff then
      local light = DynamicLight(v:EntIndex())

      if light then
        light.pos = v:GetShootPos()
        light.r = 255
        light.g = 255
        light.b = 255
        light.dir = v:EyeAngles():Forward()
        light.innerangle = 0.05
        light.outerangle = 0.15
        light.minlight = 0.2
        light.brightness = 1
        light.decay = 1000
        light.size = 128
        light.dietime = cur_time + 0.5
      end
    end
  end
end
