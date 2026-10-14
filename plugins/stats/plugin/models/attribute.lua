--- Database record of one attribute of a character: the attribute ID and the level. Belongs
-- to a `Character` and has many `AttributeBoost` records.
-- @module [Attribute]

class 'Attribute' extends 'ActiveRecord::Base'

Attribute:belongs_to  'Character'
Attribute:has_many    'attribute_boosts'
