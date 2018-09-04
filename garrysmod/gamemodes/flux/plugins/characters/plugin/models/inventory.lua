class 'Inventory' extends 'ActiveRecord::Base'

Inventory:belongs_to 'Character'
Inventory:has_many 'character_items'
