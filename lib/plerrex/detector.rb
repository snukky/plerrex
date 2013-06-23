#encoding:utf-8

require 'diff-lcs'
require 'logger'

require 'plerrex/ext/sentence_splitter'
require 'plerrex/edited_text'
require 'plerrex/error_correction'
require 'plerrex/recognizer'
require "plerrex/validator"

module Plerrex
  class Detector 
    attr_reader :logger

    MIN_TEXT_LENGTH = 15
    MIN_SENTENCE_LENGTH = 4
    MAX_SENTENCE_LENGTH = 85

    MAX_WORDS_IN_CHANGE = 2
    MAX_DIFFERENCE_IN_CHARACTERS = 7

    MAX_REJECTED_ERRORS = 1
    MAX_ACCEPTED_ERRORS = 3

    ALLOWED_SIGNS = '[ a-zA-Z' \
                    + String::SMALL_TO_BIG_PL.keys.join \
                    + String::SMALL_TO_BIG_PL.values.join \
                    + '()\[\].,:;?!\-"]'
  
    def initialize(options={})
      @recognizer = Recognizer.new
      @validator = Validator.new

      @logger = Logger.new(STDOUT)
      @logger.level = options[:log] ? Logger::DEBUG : Logger::FATAL
    end

    def find(old_text, new_text)
      return [] unless looks_like_text_edition?(old_text, new_text)

      edited_texts = []

      for_each_sentence_pair(old_text, new_text) do |old_sentence, new_sentence|
        next unless looks_like_sentence_edition?(old_sentence, new_sentence)
        
        diffs = Diff::LCS.diff(old_sentence.split, new_sentence.split)
        next if too_many_diffs?(diffs.size)

        found_errors = find_errors_in_diffs(diffs)

        unless found_errors.empty?
          next unless enough_solid_errors?(found_errors, diffs.size)

          is_valid = @validator.valid_sentence?(new_sentence)
          edited_texts << EditedText.new(old_sentence, 
                                         new_sentence, 
                                         found_errors, 
                                         { :valid_sentence => is_valid })
        end
      end

      return edited_texts 
    end
  
    private

    def find_errors_in_diffs(diffs)
      clear_instance_variables
      found_errors = []
      rejected_errors = 0

      diffs.each do |diff|
        break if rejected_errors > MAX_REJECTED_ERRORS

        @old, @new = diff.partition { |change| change.action == '-' }

        unless might_be_an_error_correction?
          rejected_errors += 1
          @logger.debug("Can't be an error correction: #{@old} -> #{@new}")
          next
        end

        error, correction = diffs_to_texts(@old, @new)
        @logger.debug("Accepted edition: #{error} -> #{correction}")

        error_type, attributes = @recognizer.recognize(error, correction)
        @logger.debug("Correction: #{error_type} #{attributes.inspect}")
        
        if error_type == Recognizer::REJECTED_ERROR
          rejected_errors += 1
          next
        end
   
        position = @old.empty? ? @new.first.position : @old.first.position
        attributes.merge!({ :category => error_type })
        found_errors << ErrorCorrection.new(error, correction, position, attributes)
      end
      
      found_errors
    end

    def clear_instance_variables
      @old = nil 
      @new = nil
    end
 
    def enough_solid_errors?(errors, diffs_number)
      return false if (diffs_number - errors.size) > MAX_REJECTED_ERRORS
      return false if errors.size > MAX_ACCEPTED_ERRORS 
      return false if sensitive_and_rejected_errors_together?(errors.map(&:category)) \
                      and (errors.size != diffs_number)

      return true
    end

    def sensitive_and_rejected_errors_together?(error_types)
      !(error_types & Recognizer::SENSITIVE_ERRORS).empty?
    end

    def looks_like_text_edition?(old_text, new_text)
      return false if old_text.nil? or new_text.nil? \
                       or old_text.empty? or new_text.empty?

      if too_short_texts?(old_text, new_text)
        @logger.debug("Too short texts")
        return false
      end

      if too_big_difference_in_text_length?(old_text.size, new_text.size)
        @logger.debug("Too big difference in text lengths")
        return
      end

      return true
    end

    def too_short_texts?(a, b)
      a.size < MIN_TEXT_LENGTH or b.size < MIN_TEXT_LENGTH
    end

    def too_big_difference_in_text_length?(a, b)
      (a - b).abs > (MAX_ACCEPTED_ERRORS * MAX_DIFFERENCE_IN_CHARACTERS)
    end

    def too_many_diffs?(number)
      number > MAX_ACCEPTED_ERRORS + MAX_REJECTED_ERRORS
    end

    def for_each_sentence_pair(old_text, new_text, &block)
      old_text = merge_new_lines(old_text)
      new_text = merge_new_lines(new_text)

      old_sentences = SRX::Polish::SentenceSplitter.new(old_text).sentences
                        .map(&:strip)
      new_sentences = SRX::Polish::SentenceSplitter.new(new_text).sentences
                        .map(&:strip)

      [old_sentences.size, new_sentences.size].min.times do |i| 
        yield old_sentences[i], new_sentences[i] 
      end

      return old_sentences.size
    end

    def merge_new_lines(text)
      begin
        return text.gsub(/ *\n+ */, ' ')
      rescue
        return text
      end
    end

    def looks_like_sentence_edition?(old, new)
      if old.empty? or new.empty? or old == new
        @logger.debug("Texts are empty or equal")
        return false
      end
      
      smaller_size, larger_size = [old.split.size, new.split.size].sort

      if smaller_size < MIN_SENTENCE_LENGTH or larger_size > MAX_SENTENCE_LENGTH
        @logger.debug("Too short or too long texts")
        return false
      end

      return false if @validator.wiki_artifact?(old) or @validator.wiki_artifact?(new)

      return true
    end

    def diffs_to_texts(*diffs)
      diffs.inject([]) do |diffs, diff| 
        diffs << diff.map { |change| change.element }.join(' ') 
      end
    end

    # The parameters are Arrays of Diff objects 
    def might_be_an_error_correction?
      if too_many_words?
        @logger.debug("Too many words changed in edition")
        return false
      end

      if difference_in_words_count?
        @logger.debug("Difference in the number of words in edition")
        return false
      end

      if too_big_difference_in_length?
        @logger.debug("Too large length difference in edition")
        return false
      end

      if non_words_change?
        @logger.debug("No word changed in edition")
        return false
      end
      
      return true
    end
  
    def too_many_words?
      @old.size > MAX_WORDS_IN_CHANGE or @new.size > MAX_WORDS_IN_CHANGE
    end

    def difference_in_words_count?
      @old.size != @new.size unless @old.empty? or @new.empty?
    end
  
    def too_big_difference_in_length?
      length_old = @old.inject(0) { |sum, e| sum += e.element.size } 
      length_new = @new.inject(0) { |sum, e| sum += e.element.size }

      difference = (length_old - length_new).abs
      difference -= MAX_WORDS_IN_CHANGE if length_old.zero? or length_new.zero?

      difference > MAX_DIFFERENCE_IN_CHARACTERS
    end

    def non_words_change?
      in_old = @old.any? { |e| e.element !~ /^#{ALLOWED_SIGNS}*$/ }
      in_new = @new.any? { |e| e.element !~ /^#{ALLOWED_SIGNS}*$/ }
     
      in_old or in_new
    end

  end
end
