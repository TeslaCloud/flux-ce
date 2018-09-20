config.add_to_menu('character', 'character_min_name_len', t'char_config.min_name_len', t'char_config.min_name_len_desc', 'number', {min = 1, max = 256, default = 4})
config.add_to_menu('character', 'character_max_name_len', t'char_config.max_name_len', t'char_config.max_name_len_desc', 'number', {min = 1, max = 256, default = 32})
config.add_to_menu('character', 'character_min_desc_len', t'char_config.min_desc_len', t'char_config.min_desc_len_desc', 'number', {min = 1, max = 1024, default = 32})
config.add_to_menu('character', 'character_max_desc_len', t'char_config.max_desc_len', t'char_config.max_desc_len_desc', 'number', {min = 1, max = 1024, default = 256})
