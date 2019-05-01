local ent_meta = FindMetaTable 'Entity'

function ent_meta:prevent_transmit(target, should_prevent)
  if IsValid(target) then
    self:SetPreventTransmit(target, should_prevent)

    for k, child in ipairs(self:GetChildren()) do
      if IsValid(child) then
        child:prevent_transmit(target, should_prevent)
      end
    end
  end
end

function ent_meta:prevent_transmit_conditional(should_prevent, condition)
  condition = condition or function() return true end

  for k, v in ipairs(player.all()) do
    if v != self and condition(v, self, should_prevent) != false then
      self:prevent_transmit(v, should_prevent)
    end
  end

  -- Let the entity itself know it's gone.
  self:set_nv('transmission_prevented', should_prevent, self)
end
