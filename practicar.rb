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
    @available_spanish_voices = `say -v ?| grep es_`.lines.map{|l| l.split(" ").first}

  end

  def run
    while not @exit_signal do
      input = nil
      next_question!()
      question_stats = @stats["question_stats"][@current_question]

      effective_max_threshold = @max_threshold - @min_threshold
      effective_threshold = @current_threshold - @min_threshold
      effective_question_cutoff = calc_question_cutoff(question_stats) - @min_threshold
      success_chance = 100 * (effective_question_cutoff.to_f / effective_max_threshold)

      puts "━" * 78
      print_question_stat "Step",                       @stats["step"]
      print_question_stat "points",                     @stats["points"]
      print_question_stat "Thresholds",                 "#{@min_threshold}...[#{calc_question_cutoff(question_stats)}]...|#{@current_threshold}...#{@max_threshold}"
      print_question_stat "Effective Threshold",        "0...[#{effective_question_cutoff}]...|#{effective_threshold}...#{effective_max_threshold}"
      print_question_stat "Question last correct step", question_stats["last_correct_step"], @stats["step"] - question_stats["last_correct_step"]
      print_question_stat "Question last wrong step",   question_stats["last_wrong_step"], @stats["step"] - question_stats["last_wrong_step"]
      print_question_stat "Question points",            question_stats["question_points"]
      print_question_stat "Success chance",             sprintf("%.2f%%", success_chance)
      puts

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
      print_question_stat "Question new cutoff", calc_question_cutoff(question_stats) - @min_threshold
      print_question_stat "Question new points", question_stats["question_points"]
      @stats["step"] += 1
      save_stats()
    end
  end

  private

  def print_question_stat(name, value, effective_value = nil)
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
    puts %("#{@current_question}":)
    user_input = gets().chomp rescue nil
    goodbye() if user_input.nil?
    if user_input == convert_accents(@current_answer) # Perfect answer

      is_correct = true
      puts "CORRECT!"

    elsif remove_accents(user_input) == remove_accents(@current_answer) # Imperfect answer
      is_correct = true
      puts "Almost correct: \"#{@current_answer}\""
    else # Wrong answer
      is_correct = false
      puts "Wrong!\t The correct answer is: \t '#{@current_answer}'"
    end

    spanish_say(@current_answer)
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

    spanish_say "la puntuación: #{points_made}"
    puts "\nGoodbye.\n"
    exit 0
  end

  def spanish_say(word)
    system %(say -v #{@available_spanish_voices.sample} "#{word}" &)
  end

  def next_question!()
    current_step = @stats["step"]
    possible_thresholds = @stats["question_stats"].values.map {|q| calc_question_cutoff(q)}

    @min_threshold = possible_thresholds.min
    @max_threshold = possible_thresholds.max
    @current_threshold = Random.rand(@min_threshold..@max_threshold)

    possible_questions = @stats["question_stats"].select { |question, question_stats|
      calc_question_cutoff(question_stats) <= @current_threshold
    }

    @current_question = possible_questions.keys.sample
    @current_answer = possible_questions[@current_question]["answer"]
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
