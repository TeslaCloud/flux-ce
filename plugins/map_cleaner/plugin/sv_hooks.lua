--- Server side of the Map Cleaner plugin: cleans the map once it has loaded and after every
-- map cleanup.

--- Removes the unwanted entities of the map once all of its entities have been created.
function MapCleaner:InitPostEntity()
  self:clean()
end

--- Removes the unwanted entities again after a map cleanup has put them back.
function MapCleaner:PostCleanupMap()
  self:clean()
end
