#
# This script is used to convert Font-Awesome .css files
# into a Lua table.
#
# Requirements:
# Ruby 2.4 or newer.
#
# Usage:
# ruby converter.rb all.css all.lua
#

if !ARGV[0] or !ARGV[1]
  puts "convert.rb <input> <output>"
  return
end

@input_file = ARGV[0]
@output_file = ARGV[1]

contents = File.read @input_file
output = "local fa_data = {\n"
longest_key = 0

contents.gsub! /\n/, ''

match_data = contents.scan /\.fa\-([a-zA-Z0-9\-]*):before\s*{\s*content:\s*"([\\a-zA-Z0-9]*)"[;]*\s*}/

match_data.each do |m|
  len = m[0].length

  if len > longest_key
    longest_key = len
  end
end

match_data.each do |m|
  spaces = longest_key - m[0].length + 1
  output += "  ['fa-#{m[0]}']#{' ' * spaces}= '#{m[1].gsub!(/\\/, '')}',\n"
end

output = output.chomp ",\n"
output += "\n}\n"

File.write @output_file, output
