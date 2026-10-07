TOOL.Category = 'Flux'
TOOL.Name = 'Mapscene tool'
TOOL.Command = nil
TOOL.ConfigName = ''
TOOL.permission = 'mapscenes'

--- Adds a mapscene point at the owner's eye position, facing where they are looking.
-- @param trace [Map trace result of the tool owner's aim]
-- @return [Boolean true if the point was added (always true clientside), nil if the owner
--   is not valid or lacks the 'mapsceneadd' permission]
function TOOL:LeftClick(trace)
  if CLIENT then return true end

  local owner = self:GetOwner()

  if !IsValid(owner) or !owner:can('mapsceneadd') then return end

  Mapscenes:add_point(owner:EyePos(), owner:GetAngles())

  owner:notify('notification.mapscene.point_added')

  return true
end

--- Builds the tool's settings panel: a list of the mapscene points that can be deleted
-- through a right click. Adds nothing without the 'mapscenes' permission.
-- @param CPanel [Panel the tool's control panel]
function TOOL.BuildCPanel(CPanel)
  if !can('mapscenes') then return end

  local list = vgui.Create('DListView')
  list:SetSize(30, 90)
  list:AddColumn(t'ui.mapscene.title')
  list.Think = function(panel)
    if #Mapscenes.points != #list:GetLines() then
      list:Clear()

      for k, v in pairs(Mapscenes.points) do
        local line = list:AddLine(t'ui.mapscene.title'..' #'..k)
        line.id = k
      end
    end
  end

  list.OnRowRightClick = function(panel, line)
    if !can('mapscenes') then return end

    local menu = DermaMenu()
    menu:AddOption('delete', function()
      Cable.send('fl_mapscene_remove', line)
      list:RemoveLine(line)
    end):SetIcon('icon16/cancel.png')
    menu:Open()

    RegisterDermaMenuForClose(menu)
  end

  CPanel:AddItem(list)
end
