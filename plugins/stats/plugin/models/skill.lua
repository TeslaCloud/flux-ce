--- Database record of one skill of a character: the skill ID and the rank. Belongs to a
-- `Character`.
-- @module [Skill]

class 'Skill' extends 'ActiveRecord::Base'

Skill:belongs_to 'Character'
