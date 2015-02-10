#!/usr/bin/env ruby

require 'yaml'
data = YAML.load(File.read(File.expand_path("../numbers.json", __FILE__)))
max = data["max"]
while true
  number = (0..max).to_a.sample
  puts %(Translate "#{number}":)
  input = gets().chomp
  correct_translation = data["numbers"][number.to_s]
  is_correct = input == correct_translation
  if is_correct
    puts "CORRECT!"
  else
    puts "WRONG! the correct translation is: #{correct_translation}"
  end
end
