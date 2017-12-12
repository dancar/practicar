#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

#TODO:
# Better way to deal with accents?

require 'json'
require './speech.rb'

class Practicar
  DEFAULT_QUESTIONS_FILE = "questions.json"
  AVAILABLE_MODES = [:smart, :random]
  ANSWER_PLACEHOLDER = /\(\?\)/ # answers for questions containing "(?)" (without quotes) will be voiced as the questions with (?) replaced by the answer
  DEFAULT_STATS = {
    "points" => 0,
    "step" => 0,
    "question_stats" => {}
  }

  STRINGS = {
    "es"=> {
      points: "la puntuación: %s"
    },

    "de" => {
      points: "Die Punktzahl: %s"
    }

  }

  def initialize(questions_file = DEFAULT_QUESTIONS_FILE, mode = :smart)
    @mode = mode.downcase.to_sym
    raise "Invalid mode: #{@mode}" unless AVAILABLE_MODES.include?(@mode)

    @stats_file = stats_file_for_questions_file(questions_file)
    @stats = read_json_file(@stats_file) rescue DEFAULT_STATS
    question_file_data = read_json_file(questions_file)
    @language = question_file_data["language"]
    available_questions = question_file_data["questions"]

    # init question stats:
    available_questions.each do |question, answer|
      question_stats = (@stats["question_stats"][question] ||= {})
      question_stats["answer"] = answer
      question_stats["last_correct_step"] ||= 0
      question_stats["last_wrong_step"] ||= 0
      question_stats["question_points"] ||= 0
    end

    # Remove inexistent questions:
    @stats["question_stats"].select! do |question, stats|
      available_questions.key?(question)
    end

    @initial_step = @stats["step"]
    @initial_points = @stats["points"]
    @speech = Speech.new()

  end

  def run
    while true do
      next_question!()
      question_stats = @stats["question_stats"][@current_question]
      is_correct = ask_current_question()
      if is_correct
        @stats["points"] += 1
        question_stats["last_correct_step"] = @stats["step"]
        question_stats["last_correct_time"] = Time.new
        question_stats["question_points"] += 1
      else
        question_stats["question_points"] -= 1
        question_stats["last_wrong_step"] = @stats["step"]
        # Repeat the same question until answered correctly:
        until is_correct
          is_correct = ask_current_question()
        end
      end
      puts
      # print_question_stat "Question new cutoff", calc_question_cutoff(question_stats) - @min_threshold
      # print_question_stat "Question new points", question_stats["question_points"]
      @stats["step"] += 1
      save_stats()
    end
  end

  private

  # Returns a hash of language_code -> array voice names
  def print_question_stat(name, value, effective_value = nil)
    return unless ENV["SHOW_STATS"]
    str = sprintf("▹ %30s: %s", name, value.to_s)
    str << " (#{effective_value})" if effective_value
    puts str
  end

  def convert_accents(word)
    ans = word.clone
    {
      "á" => "a'",
      "ć" => "c'",
      "é" => "e'",
      "í" => "i'",
      "ń" => "n'",
      "ñ" => "n~",
      "ó" => "o'",
      "ś" => "s'",
      "ú" => "u'",
      "ü" => "u^",
      "ź" => "z'"
    }.each do |k, v|
      ans.gsub!(k, v)
    end

    ans
  end

  def remove_accents(word)
    ans = word.clone
    {
      "a" => ["á", "a'"],
      "c" => ["ć", "c'"],
      "e" => ["é", "e'"],
      "i" => ["í", "i'"],
      "n" => ["ń", "n'", "ñ", "n~"],
      "o" => ["ó", "o'"],
      "s" => ["ś", "s'"],
      "u" => ["ú", "u'", "ü", "u^"],
      "z" => ["ź", "z'"]
    }.each do |target, sources|
        sources.each do |source|
          ans.gsub!(source, target)
        end
    end
    ans
  end

  def ask_current_question()
    puts @current_question + ":"
    say(@current_question, "en")
    user_input = STDIN.gets()
    goodbye() if user_input.nil? # Exiting by entering CTRL + D
    user_input.chomp!.downcase!
    if user_input == @current_answer or user_input == convert_accents(@current_answer) # Perfect answer

      is_correct = true
      puts "CORRECT!"

    elsif remove_accents(user_input) == remove_accents(@current_answer) # Imperfect answer
      is_correct = true
      puts "Almost correct: \"#{@current_answer}\""
    else # Wrong answer
      is_correct = false
      puts "Wrong!\t The correct answer is: \t '#{@current_answer}'"
    end

    # if the question contains ANSWER_PLACEHOLDER, we want to say the question itself with the placeholder replaced by the answer
    # i.e the question "yesterday they (?) walked" with the answer "have" would be voiced: "yesterday they have walked" instead of just "have"
    full_answer = @current_answer
    if @current_question.match(ANSWER_PLACEHOLDER)
      full_answer = @current_question.gsub(ANSWER_PLACEHOLDER, @current_answer)
      full_answer.gsub!(/\([^)]+\)/,"")
    end

    say(full_answer, @language)
    is_correct
  end

  def goodbye
    points_made = @stats["points"] - @initial_points
    questions_taken = @stats["step"] - @initial_step
    puts "\n"

    print "Questions taken: #{ questions_taken } "
    puts "✱ " * questions_taken

    print "Points made: #{points_made} "
    puts "☆ " * points_made

    say(STRINGS[@language][:points] % points_made, @language)
    puts "\nGoodbye.\n"
    exit 0
  end

  def say(word, language)
    @speech.say(word, language)
  end

  def next_question!()
    return smart_next_question! if @mode == :smart
    return random_next_question!() if @mode == :random
  end

  def random_next_question!()
    @current_question = @stats["question_stats"].keys.sample
    @current_answer = @stats["question_stats"][@current_question]["answer"]
  end

  def smart_next_question!()
    possible_thresholds = @stats["question_stats"].values.map {|q| calc_question_cutoff(q)}

    @min_threshold = possible_thresholds.min
    @max_threshold = possible_thresholds.max
    @current_threshold = Random.rand(@min_threshold..@max_threshold)

    possible_questions = @stats["question_stats"].select { |question, question_stats|
      calc_question_cutoff(question_stats) <= @current_threshold
    }

    @current_question = possible_questions.keys.sample
    @current_answer = possible_questions[@current_question]["answer"].downcase
  end

  def calc_question_cutoff(question_stats)
    # A low cutoff means higher chances of selection

    # Increase cutoff if the question hasn't been answered in a long time:
    cutoff = question_stats["last_correct_step"]

    # Decrease cutoff if the question has been answered correctly after not being asked for a long time:
    cutoff += question_stats["last_correct_step"] - question_stats["last_wrong_step"]

    # Decrease cutoff if the question has been answered correctly many times:
    cutoff += question_stats["question_points"]

    cutoff
  end

  def save_stats()
    File.write(file_path(@stats_file), @stats.to_json)
  end

  def read_json_file(name)
    JSON.load(File.read(file_path(name)))
  end

  def file_path(name)
    File.expand_path(File.join("..", name), __FILE__)
  end

  def stats_file_for_questions_file(questions_file_name)
    questions_file_name + ".stats"
  end
end

Practicar.new(*ARGV).run
