TOOL.Category = 'Flux'
TOOL.Name = 'Mapscene tool'
TOOL.Command = nil
TOOL.ConfigName = ''

function TOOL:LeftClick(trace)
  if CLIENT then return true end

  local player = self:GetOwner()

  if !IsValid(player) or !player:can('mapsceneadd') then return end

  Mapscenes:add_point(player:EyePos(), player:GetAngles())

  fl.player:notify(player, 'mapscene.point_added')

  return true
end

function TOOL.BuildCPanel(CPanel)
  local list = vgui.Create('DListView')
  list:SetSize(30, 90)
  list:AddColumn(t'mapscene.title')
  list.Think = function(panel)
    if #Mapscenes.points != #list:GetLines() then
      list:Clear()

      for k, v in pairs(Mapscenes.points) do
        local line = list:AddLine(t'mapscene.title'..' #'..k)
        line.id = k
      end
    end
  end

  list.OnRowRightClick = function(panel, line)
    local menu = DermaMenu()
    menu:AddOption('delete', function()
      cable.send('flRemoveMapscene', line)
      list:RemoveLine(line)
    end):SetIcon('icon16/cancel.png')
    menu:Open()

    RegisterDermaMenuForClose(menu)
  end

  CPanel:AddItem(list)
end
