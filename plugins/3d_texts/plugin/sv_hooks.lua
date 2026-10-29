--- Server-side hook handlers of the 3D Texts plugin: sending the texts and pictures to a
-- player who has initialized, and loading and saving them with the data of the framework.

local cable_send = Cable.send

--- Sends all stored 3D texts and pictures to the player who has just initialized.
-- @param actor [Player]
function SurfaceText:PlayerInitialized(actor)
  cable_send(actor, 'fl_surface_text_load', self.texts)
  cable_send(actor, 'fl_surface_picture_load', self.pictures)
end

--- Loads the stored 3D texts and pictures when the framework loads its data.
function SurfaceText:LoadData()
  self:load()
end

--- Saves the 3D texts and pictures when the framework saves its data.
function SurfaceText:SaveData()
  self:save()
end
