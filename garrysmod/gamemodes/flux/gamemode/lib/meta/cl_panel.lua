local panel_meta = FindMetaTable('Panel')

-- Seriously, Newman? I have to write this myself?
function panel_meta:UnDraggable()
  self.m_DragSlot = nil
end

function panel_meta:SafeRemove()
  self:SetVisible(false)
  self:Remove()
end

function panel_meta:SetPosEx(x, y)
  self:SetPos(font.Scale(x), font.Scale(y))
end

function panel_meta:SetSizeEx(w, h)
  self:SetSize(font.Scale(w), font.Scale(h))
end
