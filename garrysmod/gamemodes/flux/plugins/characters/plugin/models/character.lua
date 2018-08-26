ActiveRecord.define_model('Character', function(t)
  t:string { 'steam_id', null = false }
  t:string { 'name', null = false }
  t:string 'model'
  t:text 'phys_desc'
  t:integer 'money'
  t:integer 'character_id'
end)

Character:belongs_to 'User'
Character:has_many 'data'
Character:has_one 'inventory'
Character:has_one 'ammo'

function Character:restored()
  if self.user then
    hook.Run("RestoreCharacter", self.user.player, self.id, self)
  end
end
