--- The Mapscene tool: left click adds a mapscene camera point at the user's eyes, and the
-- tool's settings panel lists the points and lets them be deleted.
-- The tool, adding a point and the list of points are all tied to the 'mapscenes' permission.

TOOL.Category = 'Flux'
TOOL.Name = 'Mapscene tool'
TOOL.Command = nil
TOOL.ConfigName = ''
TOOL.permission = 'mapscenes'

--- Adds a mapscene point at the owner's eye position, facing where they are looking.
-- @param _trace [Map trace result of the tool owner's aim]
-- @return [Boolean true if the point was added (always true clientside), nil if the owner
--   is not valid or lacks the 'mapscenes' permission]
function TOOL:LeftClick(_trace)
  if CLIENT then return true end

  local owner = self:GetOwner()

  if !IsValid(owner) or !owner:can('mapscenes') then return end

  Mapscenes:add_point(owner:EyePos(), owner:GetAngles())

  owner:notify('notification.mapscene.point_added')

  return true
end

--- Builds the tool's settings panel: a list of the mapscene points that can be deleted
-- through a right click. Adds nothing without the 'mapscenes' permission.
-- @param CPanel [Panel the tool's control panel]
function TOOL.BuildCPanel(CPanel)
  if !can('mapscenes') then return end

  local point_list = vgui.Create('DListView')
  point_list:SetSize(30, DermaScale.scale(90))
  point_list:AddColumn(t'ui.mapscene.title')
  point_list.Think = function(_panel)
    if #Mapscenes.points != #point_list:GetLines() then
      point_list:Clear()

      for point_id in pairs(Mapscenes.points) do
        local line = point_list:AddLine(t('ui.mapscene.point', { index = point_id }))
        line.id = point_id
      end
    end
  end

  point_list.OnRowRightClick = function(_panel, line)
    if !can('mapscenes') then return end

    local menu = DermaMenu()
    menu:AddOption('delete', function()
      Cable.send('fl_mapscene_remove', line.id)
    end):SetIcon('icon16/cancel.png')
    menu:Open()

    RegisterDermaMenuForClose(menu)
  end

  CPanel:AddItem(point_list)
end
