class Speech

  DISABLED_EN_VOICES = ["Albert", "Fred", "Bubbles", "Bahh", "Bells", "Boing", "Deranged", "Hysterical", "Junior", "Princess", "Ralph", "Samantha", "Tessa", "Zarvox", "Cellos", "Whisper"]
  def initialize()
    @available_voices = get_voices()
  end
  def get_voices
    voices_map = %x(say -v ?).lines.map{|l| l.split(" ")}.reduce({}) do |ans, item|
      language = item[1][0..1]
      ans[language] ||= []
      ans[language] << item[0]
      ans
    end
    voices_map["en"] = voices_map["en"] - DISABLED_EN_VOICES
    voices_map
  end
  def say(word, language)
    return if ENV["NOSPEAK"]
    voice = @available_voices[language].sample
    system %(say -v #{voice} "#{word}" )
  end

end
