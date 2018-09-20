class 'Character' extends 'ActiveRecord::Base'

Character:belongs_to 'User'
Character:has_many 'data'
Character:has_one 'ammo'

function Character:restored()
  if self.user then
    hook.run('RestoreCharacter', self.user.player, self.id, self)
  end
end
