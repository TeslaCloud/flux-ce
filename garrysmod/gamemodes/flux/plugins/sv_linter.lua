-- WIP WIP WIP

PLUGIN:set_name('Linter')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Yells at you for stylistic mistakes.')

if !Flux.development then return end

local linter_options = {
  indent_size                 = 2,
  indent_spaces               = true,
  incorrent_indent            = 'error',
  final_newline               = true,
  logic_max_depth             = 6,
  logic_depth_exceeded        = 'warn',
  spaces_around_table_content = true,
  spaces_around_argument_list = 'error',
  spaces_around_table_index   = 'error',
  space_before_comma          = 'error',
  space_after_comma           = true,
  space_before_argument_list  = 'error',
  string_opener               = "'",
  incorrect_string_opener     = 'warn',
  empty_lines                 = 'warn',
  newline_before_return       = 'ignore',
  newline_after_local         = 'ignore',
  brackets_around_single      = 'ignore',
  max_function_name_length    = 24,
  function_name_exceeded      = 'warn',
  semicolons                  = 'error'
}
