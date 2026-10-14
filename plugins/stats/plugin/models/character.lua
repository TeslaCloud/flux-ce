--- Gives the `Character` model its `attributes` association, the `Attribute` records of the
-- character, and its `skills` association, the `Skill` records of the character.

Character:has_many 'attributes'
Character:has_many 'skills'
