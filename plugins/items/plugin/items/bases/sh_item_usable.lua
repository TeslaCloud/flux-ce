--- ItemUsable is the base class for items that do something when they are used.
-- A derived item overrides `use(actor)` with its effect and, to forbid the use in some
-- cases, `can_use(actor)`. The `max_uses` field sets how many times the item can be used
-- before it is removed from the inventory, 1 by default. The uses that are left are kept
-- in the `uses` field of the instance; when `max_uses` is above 1 they are shown in the
-- name of the item and on its inventory slot, and the weight of the item shrinks with them.

class 'ItemUsable' extends 'ItemBase'

ItemUsable.name = 'Usable Items Base'
ItemUsable.description = 'An item that can be used.'
ItemUsable.max_uses = 1

if CLIENT then
  --- Called when the inventory slot of the item is painted over.
  -- Draws the amount of uses left if the item can be used more than once.
  -- @param w [Number width of the slot panel]
  -- @param h [Number height of the slot panel]
  function ItemUsable:paint_over_slot(w, h)
    if self.max_uses > 1 then
      local text = self:get_uses()..'/'..self.max_uses
      local font = Theme.get_font('text_smallest')
      local text_w, text_h = util.text_size(text, font)
      draw.SimpleText(text, font, w - text_w - math.scale_x(4), math.scale(4), Color(225, 225, 225))
    end
  end
end

--- Returns the translated name of the item,
-- followed by the amount of uses left if the item can be used more than once.
-- @return [String]
function ItemUsable:get_name()
  return t(self.name)..(self.max_uses > 1 and ' ['..self:get_uses()..'/'..self.max_uses..']' or '')
end

--- Returns the weight of the item, scaled by the share of uses it has left.
-- @return [Number]
function ItemUsable:get_weight()
  return math.round(self.weight * self:get_uses() / self.max_uses, 1)
end

--- Returns the amount of uses the item has left.
-- @return [Number]
function ItemUsable:get_uses()
  return self.uses or self.max_uses
end

--- Called on the server by the 'PlayerUseItem' hook when a player uses the item.
-- Calls ItemUsable:use unless ItemUsable:can_use returns false, and spends one use.
-- Returning nothing/nil removes the item from the inventory as soon as it's used,
-- false prevents the item from being used at all,
-- true prevents the item from being removed upon use.
-- @param actor [Player]
-- @return [Boolean true if there are uses left, false if it cannot be used, nil if used up]
function ItemUsable:on_use(actor)
  if self:can_use(actor) != false then
    self:use(actor)

    self.uses = (self.uses or self.max_uses) - 1

    if self.uses > 0 then
      return true
    end
  else
    return false
  end
end

--- Called by ItemUsable:on_use when a player uses the item.
-- Override it to make the item do something.
-- @param actor [Player]
function ItemUsable:use(actor)
end

--- Called by ItemUsable:on_use before the item is used.
-- Override it and return false to prevent the item from being used.
-- @param actor [Player]
-- @return [Boolean false to prevent the use, nil otherwise]
function ItemUsable:can_use(actor)
end
