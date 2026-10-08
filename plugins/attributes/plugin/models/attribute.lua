--- Database record of one attribute of a character: the attribute ID, the level and the
-- progress. Belongs to a `Character` and has many `AttributeMultiplier` and
-- `AttributeBoost` records.
-- @module [Attribute]

class 'Attribute' extends 'ActiveRecord::Base'

Attribute:belongs_to  'Character'
Attribute:has_many    'attribute_multipliers'
Attribute:has_many    'attribute_boosts'
