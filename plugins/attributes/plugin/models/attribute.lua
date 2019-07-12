class 'Attribute' extends 'ActiveRecord::Base'

Attribute:belongs_to  'Character'
Attribute:has_many    'attribute_multipliers'
Attribute:has_many    'attribute_boosts'
