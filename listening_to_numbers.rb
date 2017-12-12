#!/usr/bin/env ruby

require './speech.rb'
MIN = 0
MAX = 100
speech = Speech.new()
language = "de"
while true do
  user_input = nil
  number = rand(MIN..MAX)
  until user_input == number.to_s do
    puts "Wrong" if user_input
    speech.say(number, language)
    user_input = STDIN.gets().chomp!
  end
  puts "CORRECT"
end
