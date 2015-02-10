#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'json'
class Practicar
  STATS_FILE = "stats.json"
  QUESTIONS_FILE = "questions.json"
  DEFAULT_STATS = {
    "points" => 0,
    "step" => 0,
    "question_stats" => {}
  }

  def initialize
    @stats = read_json_file(STATS_FILE) rescue DEFAULT_STATS
    available_questions = read_json_file(QUESTIONS_FILE)
    available_questions.each do |question, answer|
      @stats["question_stats"][question] ||= {
        "last_correct_step" => 0,
        "last_wrong_step" => 0,
      }
      @stats["question_stats"][question]["answer"] = answer
    end

    # Remove inexistent questions:
    @stats["question_stats"].select! do |question, stats|
      available_questions.key?(question)
    end

    @initial_step = @stats["step"]
    @initial_points = @stats["points"]
    @available_spanish_voices = `say -v ?| grep es_`.lines.map{|l| l.split(" ").first}

  end

  def run
    while not @exit_signal do
      input = nil
      next_question!()
      is_correct = ask_current_question()
      question_stats = @stats["question_stats"][@current_question]
      if is_correct
        @stats["points"] += 1
        question_stats["last_correct_step"] = @stats["step"]
        question_stats["last_correct_time"] = Time.new
      else
        question_stats["last_wrong_step"] = @stats["step"]
        # Repeat the same question until answered correctly:
        until is_correct
          is_correct = ask_current_question()
        end
      end
      @stats["step"] += 1
      save_stats()
    end
  end

  private

  def remove_accents(word)
    ans = word
    {
      "à" => "a",
      "ć" => "c",
      "ê" => "e",
      "í" => "i",
      "ń" => "n",
      "ñ" => "n",
      "ó" => "o",
      "ś" => "s",
      "ú" => "u",
      "ź" => "z"
    }.each do |k, v|
      ans.gsub!(k,v)
    end

    ans
  end

  def ask_current_question()
    puts %([#{@stats["points"]}] Question #{@stats["step"]}: "#{@current_question}":)
    user_input = gets().chomp rescue nil
    goodbye() if user_input.nil?

    is_correct = user_input == remove_accents(@current_answer)
    if is_correct
      puts "CORRECT!"
    else
      puts "Wrong!\t The correct answer is: \t '#{@current_answer}'"
    end
    spanish_say(@current_answer)
    is_correct
  end

  def goodbye
    puts "=" * 100
    puts "Questions taken: #{ @stats["step"] - @initial_step }"
    puts "Points made: #{@stats["points"] - @initial_points  }"
    puts "\nGoodbye.\n"
    exit 0
  end

  def spanish_say(word)
    system %(say -v #{@available_spanish_voices.sample} "#{word}" &)
  end

  def next_question!()
    current_step = @stats["step"]
    oldest_question_step = @stats["question_stats"].values.map {|q| q["last_correct_step"]}.min || 0
    threshold = Random.rand(oldest_question_step..current_step)
    possible_questions = @stats["question_stats"].select { |question, stats|
      stats["last_correct_step"] <= threshold
    }

    @current_question = possible_questions.keys.sample
    @current_answer = possible_questions[@current_question]["answer"]
  end

  def save_stats()
    File.write(file_path(STATS_FILE), @stats.to_json)
  end

  def read_json_file(name)
    JSON.load(File.read(file_path(name)))
  end

  def file_path(name)
    File.expand_path(File.join("..", name), __FILE__)
  end
end

Practicar.new.run
