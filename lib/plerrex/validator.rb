#encoding:utf-8

require 'plerrex/core_ext/string'
require 'plerrex/wiki_validator'

module Plerrex
  class Validator

    include Plerrex::WikiValidator

    attr_reader :logger
   
    PUNCTS = ',.:;?!'
    BRACKET_PAIRS = [['{', '}'], ['(', ')'], ['[', ']']]

    INVALID_BEGINNINGS = %w(< > = @ # $ ^ & * ~ / | \ — ; :)
    VALID_ENDINGS = %w(. ? ! ; :)
    VALID_BEGINNINGS = ('A'..'Z').to_a \
                       + String::BIG_TO_SMALL_PL.keys \
                       + ('0'..'9').to_a \
                       + %w(" ' —)

    LESS_IMPORTANT_ERRORS = [:punct, :case, :unknown]
                              .map{ |type| Recognizer::ERRORS[type] }
    NAMED_ENTITY_CANDIDATES = [:spell, :spell_xxx]
                                .map{ |type| Recognizer::ERRORS[type] }
  
    def initialize(options={})
      @logger = Logger.new(STDOUT)
      @logger.level = options[:log] ? Logger::DEBUG : Logger::FATAL
    end

    def valid_error?(edited_text)
      return false if unwanted_edition?(edited_text)

      if less_important_errors?(edited_text)
        return false if wiki_enumeration?(edited_text.text)
        return false if too_many_duplicated_words?(edited_text.new_text)
        return false if most_words_start_with_big_letter?(edited_text.text)
      end

      return true
    end

    def valid_sentence?(text)
      VALID_BEGINNINGS.include?(text[0]) && VALID_ENDINGS.include?(text[-1]) \
        && !unpaired_brackets?(text)
    end

    def unpaired_brackets?(text)
      BRACKET_PAIRS.any? { |a, b| text.count(a) != text.count(b) }
    end

    def invalid_beginning?(text)
      INVALID_BEGINNINGS.include?(text[0])
    end

    private
    
    def unwanted_edition?(edited_text)
      result = (edited_text.text + ':' == edited_text.new_text) \
               || (edited_text.text == edited_text.new_text + ':') \
               || (edited_text.text == edited_text.new_text + '.' \
                 && edited_text.new_text[-1] != '.')

      @logger.debug "Invalid: unwanted edition" if result && @logger
      return result
    end

    def less_important_errors?(edited_text)
      edited_text.errors.all? do |error| 
        LESS_IMPORTANT_ERRORS.include?(error.category) \
          or (NAMED_ENTITY_CANDIDATES.include?(error.category) \
            and error.correction.start_with_big_letter?)
      end
    end

    def only_given_error_types?(edited_text, *types)
      allowed_categories = types.map{ |type| Recognizer::ERRORS[type] }
      edited_text.errors.all? do |error| 
        allowed_categories.include?(error.category)
      end
    end

    def most_words_start_with_big_letter?(text, percent=0.75)
      splitted = text.split
      counted = splitted.select{ |word| word.start_with_big_letter? }.size
      result =  counted >= splitted.size*percent

      @logger.debug "Invalid: most words start with big letter" if result && @logger
      return result
    end

    def too_many_duplicated_words?(text)
      count = count_words(text)
      return false if count.size == text.split.size

      result = count.select{ |k,v| v > 1 }.values.inject(&:+) >= text.split.size / 2

      @logger.debug "Invalid: too many duplicated words" if result && @logger
      return result
    end

    def count_words(text)
      text.split.inject(Hash.new(0)){ |count, word| count[word] += 1; count }
    end

  end
end
