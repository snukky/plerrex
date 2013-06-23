#encoding:utf-8

module Plerrex
  module WikiValidator
     
    CHARS = '[a-z' + String::SMALL_TO_BIG_PL.keys.join + ']'
    BIG_CHARS = '[A-Z' + String::BIG_TO_SMALL_PL.keys.join + ']'

    WIKI_ENUMERATION = /^((#{CHARS}+ )+\(#{CHARS}+( #{CHARS}+)*\)\s?,?){2,}$/i

    WIKI_ARTIFACTS = [
      /^zobacz( też| także| również)?[: ]/i, 
      /^#{CHARS}{3,15}:/i,                  # kategoria:, plik:, http: itp.
      /^linki? /i,
      /^#{CHARS}+( #{CHARS}+)?(, #{CHARS}+( #{CHARS}+)?){3,}.{0,3}$/i,
      /( (\*|--|–|•|-) ?.{3,30}?){3,}/,     # lista elementów
      /^[a-z\-]{2,}:\w+/,                   # lista w różnych językach
      /\b#{CHARS}+\?#{CHARS}+\b/i,          # błędne kodowanie
      /(#{CHARS}+#{BIG_CHARS}#{CHARS}+.*?){3,}/,  # pozostałość tabeli
      /\|(#{CHARS}|\d)+=/i,
      /#{CHARS}+\|(#{CHARS}|\*)+/i,         # znak | w środku wyrazu
      /redirect/i
    ]

    def wiki_artifact?(text)
      WIKI_ARTIFACTS.any? { |content| text =~ content }
    end

    def wiki_enumeration?(text)
      text =~ WIKI_ENUMERATION
    end

  end
end
