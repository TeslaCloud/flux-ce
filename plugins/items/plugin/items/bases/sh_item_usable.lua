class 'ItemUsable' extends 'ItemBase'

ItemUsable.name = 'Usable Items Base'
ItemUsable.description = 'An item that can be used.'
ItemUsable.max_uses = 1

if CLIENT then
  function ItemUsable:paint_over_slot(w, h)
    if self.max_uses > 1 then
      local text = self:get_uses()..'/'..self.max_uses
      local font = Theme.get_font('text_smallest')
      local text_w, text_h = util.text_size(text, font)
      draw.SimpleText(text, font, w - text_w - math.scale_x(4), math.scale(4), Color(225, 225, 225))
    end
  end
end

function ItemUsable:get_name()
  return t(self.name)..(self.max_uses > 1 and ' ['..self:get_uses()..'/'..self.max_uses..']' or '')
end

function ItemUsable:get_weight()
  return math.round(self.weight * self:get_uses() / self.max_uses, 1)
end

function ItemUsable:get_uses()
  return self.uses or self.max_uses
end

-- Returns:
-- nothing/nil = removes item from the inventory as soon as it's used.
-- false = prevents item from being used at all.
-- true = prevents item from being removed upon use.
function ItemUsable:on_use(player)
  if self:can_use(player) != false then
    self:use(player)

    self.uses = (self.uses or self.max_uses) - 1

    if self.uses > 0 then
      return true
    end
  else
    return false
  end
end

function ItemUsable:use(player)
end

function ItemUsable:can_use(player)
end
