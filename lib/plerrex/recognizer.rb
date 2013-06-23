#encoding:utf-8

require 'polskie_stringi'
require 'damerau-levenshtein'
require 'morfologik'

require 'plerrex/core_ext/array'
require 'plerrex/core_ext/string'
require 'plerrex/ext/hunspell'
require 'plerrex/vulgarism'
require 'plerrex/thesaurus'

module Plerrex
  class Recognizer

    ERRORS = {
      :case       => 'wielkość liter',
      :diac       => 'znaki diakrytyczne',
      :diac_real  => 'znaki diakrytyczne/kontekst',
      :punct      => 'interpunkcja',
      :space      => 'pisownia łączna i rozłączna',

      :year       => 'notacja/rok',
      :age        => 'notacja/wiek',
      :abbr       => 'notacja/skrót',

      :count      => 'ilość-liczba',
      :qub        => 'się',
      :prep       => 'przyimek',
      :conj       => 'spójnik',
      :ppron      => 'zaimek',

      :infl       => 'fleksja',
      :infl_ten   => 'fleksja/czas',
      :infl_nb    => 'fleksja/liczba',
      :synt       => 'składnia',
      :sem        => 'semantyka',
      :sem_asp    => 'semantyka/aspekt',
      :sem_deg    => 'semantyka/stopień',
      :sem_style  => 'semantyka/styl',
      :style      => 'styl',

      :spell      => 'pisownia',
      :spell_xxx  => 'pisownia/prawdopodobnie',

      :unknown    => 'nierozpoznany'
    }

    REJECTED_ERROR = 'odrzucony'
  
    # Errors which don't allow any rejected error in the same sentence, e.g. 
    # inflection errors
    SENSITIVE_ERRORS = [:infl, :infl_ten, :infl_nb, 
                        :sem, :sem_asp, :sem_deg, :sem_style, 
                        :synt, :style, 
                        :qub, :perp, :conj, :ppron].map{ |e| ERRORS[e] }

    INTERPUNCTIONS = %w(, . : ; ? ! -)
    CHARS = '[a-z' + String::SMALL_TO_BIG_PL.keys.join + ']'
    PREPOSITIONS = %w(w o z za u do nad bez przy od ku mimo śród przed po pod 
      przez między obok około oprócz spoza zza znad ponad poprzez pośród 
      pomiędzy wbrew pomimo)
    YEAR_NOTATIONS = %w(rok roku rokiem rokowi r)
    AGE_NOTATIONS = %w(wiek wieku wiekiem wiekowi w)

    MIN_WORD_LENGTH = 3
    MAX_EDIT_DISTANCE = 3

    INTERPUNCTIONS_IN_THE_MIDDLE = 
      /#{CHARS}+([,:;?!]+|-{2,})#{CHARS}+|#{CHARS}{3,}\.+#{CHARS}{3,}/i

    def initialize(options={})
      @morfologik = Morfologik.new
      @hunspell = Hunspell.new("/usr/share/hunspell", "pl_PL")
      @thesaurus = Thesaurus.new

      @rm, @add = nil, nil
      # Possible types: :insertion, :deletion, :multiword, :vandalism, :unknown, 
      # :nonword, :realword
      @type = nil 
      @rm_morph, @add_morph = nil, nil
      @dist = nil
    end
  
    def recognize(removed, added)
      clear_instance_variables(removed, added)

      return rejected_error(-1)   if vulgarism?
      return rejected_error(-2)   if wrong_used_punctuation?
      return rejected_error(-3)   if change_to_uppercase?

      return error(:space)        if difference_in_spaces_or_dashes?
      return error(:punct)        if difference_in_punctuation?

      delete_external_puncts
      determine_change_type

      return rejected_error(-4)   if vandalism_change?

      return error(:qub)          if change_within_qub?
      return error(:year)         if change_with_year_notation?
      return error(:age)          if change_with_age_notation?
      
      determine_edit_distance

      if case_sensitive_change?
        return rejected_error(-5) if too_large_edit_distance?
        return error(:case)
      end

      return error(:diac_real)    if difference_in_diacritical_signs? and real_word_change?
      return error(:diac)         if difference_in_diacritical_signs?

      return rejected_error(-6)   if multiword_or_unknown_empty_change?

      if inflection_change?
        unless multiword_change?
          lemmatize_input_words

          return error(:abbr)     if change_with_abbreviation?
          return error(:infl_ten) if differ_in_tense?
          return error(:infl_nb)  if differ_in_one_value_only?("number", 
                                                               ["subst"])
        end

        return error(:infl)
      end

      if real_word_change? or empty_change?
        lemmatize_input_words if unknown_morph?
           
        return error(:count)      if change_in_quantifiers?
        return error(:prep)       if change_in_category?('prep')
        return error(:conj)       if change_in_category?('conj')
        return error(:ppron)      if change_in_category?('ppron12', 'ppron3')
                
        return rejected_error(-7) if empty_change?
  
        return error(:synt)       if grammatical_syntactic_change?
        synonyms = change_within_synonyms?

        if grammatical_semantic_change?
          return error(:sem_asp)  if differ_in_aspect?
          return error(:sem_deg)  if differ_in_one_value_only?("degree", 
                                                               ["adj", "adv"])
          return error(synonyms ? :sem_style : :sem)
        end

        return error(:style)      if synonyms
      end

      return error(:spell)        if change_as_spellchecker_suggests?
      return error(:spell_xxx)    if non_word_change?

      return rejected_error(-8)   if too_large_edit_distance?
      return rejected_error(-9)   if too_short_words?

      return error(:unknown) 
    end
 
    private
 
    def clear_instance_variables(rm, add)
      @rm = rm
      @add = add
      @type = nil
      @rm_morph = nil
      @add_morph = nil
      @dist = nil
    end

    def rejected_error(code)
      attributes = { :code => code }
      attributes[:type] = @type     unless @type.nil?
      attributes[:distance] = @dist unless @dist.nil?

      return REJECTED_ERROR, attributes
    end

    def error(category)
      attributes = {}
      attributes[:type] = @type     unless @type.nil?
      attributes[:distance] = @dist unless @dist.nil?

      return ERRORS[category], attributes
    end

    # Deletes all punctuations not included in the middle of string, i.e. at 
    # the beginning of string, at the end or close to space.
    def delete_external_puncts
      @rm = @rm.gsub(/(^| )#{INTERPUNCTIONS}+|#{INTERPUNCTIONS}+($| )/,'\1\2')
      @add = @add.gsub(/(^| )#{INTERPUNCTIONS}+|#{INTERPUNCTIONS}+($| )/,'\1\2')
    end

    def determine_change_type
      @type = case
              when @rm.empty?
                :insertion
              when @add.empty?
                :deletion
              when multiword_change?
                :multiword
              else
                if @hunspell.check(@add)
                  @hunspell.check(@rm) ? :realword : :nonword
                else
                  @hunspell.check(@rm) ? :vandalism : :unknown
                end
              end
    end

    def determine_edit_distance
      @dist = DamerauLevenshtein.distance(@rm, @add)
    end

    # --------------------------------------------------------------------------
    # easy to detect errors

    def case_sensitive_change?
      @rm.downcase == @add.downcase
    end

    def difference_in_diacritical_signs?
      @rm.no_pl == @add.no_pl
    end
  
    def difference_in_punctuation?
      delete_puncts(@rm) == delete_puncts(@add)
    end
  
    def difference_in_spaces_or_dashes?
      @rm.delete(" -") == @add.delete(" -") unless empty_change?
    end

    def change_within_qub?
      @rm == 'się' || @add == 'się' if empty_change?
    end

    def change_with_year_notation?
      YEAR_NOTATIONS.include?(@rm) and YEAR_NOTATIONS.include?(@add)
    end

    def change_with_age_notation?
      # Empty change condition because of conflict with adding or removing 
      # a preposition
      AGE_NOTATIONS.include?(@rm) && AGE_NOTATIONS.include?(@add) unless 
        [@rm, @add].sort == ["", "w"]
    end

    def change_in_quantifiers?
      return false if @rm_morph.nil? or @add_morph.nil?

      stems = (@rm_morph + @add_morph).map { |m| m[:stem] } 
      stems.include?("ilość") and stems.include?("liczba")
    end
 
    # --------------------------------------------------------------------------
    # errors detectable with lemmatizer 

    def inflection_change?
      return false if empty_change?

      rm_words = @rm.split - PREPOSITIONS
      add_words = @add.split - PREPOSITIONS

      return false if rm_words.empty? or add_words.empty?
      return false unless rm_words.size == add_words.size
      
      return rm_words.all? do |rm| 
        @morfologik.equal_stems?(rm.downcase, add_words.shift.downcase)
      end
    end

    def change_with_abbreviation?
      return false if multiword_change?

      rm_cats = @rm_morph.map{ |m| m[:category] }
      add_cats = @add_morph.map{ |m| m[:category] }

      (rm_cats.include?("brev") and !add_cats.include?("brev")) or
        (!rm_cats.include?("brev") and add_cats.include?("brev"))
    end

    def change_in_category?(*categories)
      removal = @rm_morph.map{ |m| m[:category] }.include_any_of?(categories) \
        unless @rm_morph.nil?
      return removal if @add.empty?

      addition = @add_morph.map{ |m| m[:category] }.include_any_of?(categories) \
        unless @add_morph.nil?
      return addition if @rm.empty?

      removal and addition
    end

    # Różne lematy i różne części mowy, ale odległość edycyjna poniżej progowej
    def grammatical_syntactic_change?
      return false if longer_word_is_shorter_than?(3) \
                      or unknown_morph? \
                      or too_large_edit_distance?

      rm_categories = @rm_morph.map{ |m| m[:category] }
      add_categories = @add_morph.map{ |m| m[:category] }

      !rm_categories.include_any_of?(add_categories)
    end

    # Różne lematy, ale te same części mowy i odległość edycyjna poniżej progowej
    def grammatical_semantic_change?
      return false if longer_word_is_shorter_than?(3) \
                      or unknown_morph? \
                      or too_large_edit_distance?

      rm_categories = @rm_morph.map{ |m| m[:category] }
      add_categories = @add_morph.map{ |m| m[:category] }

      rm_categories.include_any_of?(add_categories)
    end

    def change_within_synonyms?
      return false if unknown_morph?

      rm_stems = @rm_morph.map{ |m| m[:stem] }
      add_stems = @add_morph.map{ |m| m[:stem] }

      product = rm_stems.product(add_stems)
      product.any? { |pair| @thesaurus.the_same_synset?(pair[0], pair[1]) }
    end

    # Identyczne części mowy bo wykryte jako semantyczne.
    def differ_in_tense_and_aspect?
      return false unless @rm_morph.map{ |m| m[:category] }.include?("verb")
      return false unless @add_morph.map{ |m| m[:category] }.include?("verb")

      rm_vals = @rm_morph.map{ |m| m[:values] }.flatten
      add_vals = @add_morph.map{ |m| m[:values] }.flatten

      rm_vals.product(add_vals).each do |val_pair|
        #FIXME: kolejność ma znaczenie, a nie powinna mieć
        next unless val_pair[0]["aspect"] == "imperf" and val_pair[1]["aspect"] == "perf"
        next unless val_pair[0]["tense"] == "fin" and val_pair[1]["tense"] == "praet"
        next unless val_pair[0]["number"] == val_pair[1]["number"]
        next unless val_pair[0]["person"] == val_pair[1]["person"]
        return true
      end

      return false
    end

    def differ_in_one_value_only?(value, categories=[], values_to_skip=[])
      unless categories.empty?
        return false unless @rm_morph.map{ |m| m[:category] }
          .include_any_of?(categories)
        return false unless @add_morph.map{ |m| m[:category] }
          .include_any_of?(categories)
      end

      rm_vals = @rm_morph.map{ |m| m[:values] }.flatten
      add_vals = @add_morph.map{ |m| m[:values] }.flatten

      rm_vals.product(add_vals).each do |val_pair|
        next unless val_pair[0].has_key?(value) and val_pair[1].has_key?(value)
        next if val_pair[0][value] == val_pair[1][value]

        no_val1 = val_pair[0].dup
        no_val2 = val_pair[1].dup
        no_val1.delete(value)
        no_val2.delete(value)
        values_to_skip.each { |v| no_val1.delete(v); no_val2.delete(v) }

        next unless no_val1 == no_val2
        return true
      end

      return false
    end

    def differ_in_aspect?
      differ_in_tense_and_aspect? or differ_in_one_value_only?("aspect", ["verb"])
    end

    def differ_in_tense?
      differ_in_tense_and_aspect? or differ_in_one_value_only?("tense", ["verb"], ["gender"])
    end

    # --------------------------------------------------------------------------
    # errors detectable with spell checker

    def change_as_spellchecker_suggests?
      !@hunspell.check(@rm) and @hunspell.suggest(@rm).include?(@add)
    end

    def change_to_known_words_for_spellchecker?
      at_least_one_in_rm_is_wrong = @rm.split.any? { |rw| !@hunspell.check(rw) }
      all_in_add_are_correct = @add.split.all? { |aw| @hunspell.check(aw) }
      
      at_least_one_in_rm_is_wrong and all_in_add_are_correct
    end

    # --------------------------------------------------------------------------
    # errors to reject

    def vulgarism?
      all_words = @rm.split.map(&:downcase) + @add.split.map(&:downcase)
      Vulgarism.vulgarism_any_of? *all_words
        
    end

    def change_to_uppercase?
      in_rm = delete_puncts(@rm.upcase) == @rm unless @rm.empty? 
      in_add = delete_puncts(@add.upcase) == @add unless @add.empty?

      in_rm or in_add
    end

    def wrong_used_punctuation?
      at_beginning = INTERPUNCTIONS.include?(@add[0])
      in_the_middle = (@add =~ INTERPUNCTIONS_IN_THE_MIDDLE)
      at_ending = (@add =~ /#{CHARS}+([-,:;?!]{2,}|-+|\.{2,})$/i) 

      at_beginning or in_the_middle or at_ending
    end

    def change_to_unknown_word_for_spellchecker?
      !@hunspell.check(@add) unless @add.empty? or @rm.include?(' ')
    end

    def too_short_words?
      (@rm.split + @add.split).any? { |word| word.size < MIN_WORD_LENGTH }
    end

    def too_large_edit_distance?
      @dist > MAX_EDIT_DISTANCE
    end

    # --------------------------------------------------------------------------
    # helper methods

    def lemmatize_input_words
      # There is ensured that @rm and @add are single word or empty strings with
      # no punctuations
      clear_rm, clear_add = @rm.downcase, @add.downcase
      both_morph = @morfologik.stem([clear_rm, clear_add])
      
      @rm_morph = both_morph[clear_rm] if both_morph.has_key?(clear_rm)
      @add_morph = both_morph[clear_add] if both_morph.has_key?(clear_add)
    end

    def delete_puncts(str)
      str.delete(INTERPUNCTIONS.join)
    end

    def multiword_or_unknown_empty_change?
      return false unless empty_change?
      return multiword_change? \
        || (@type == :insertion and !@hunspell.check(@add)) \
        || (@type == :deletion and !@hunspell.check(@rm))
    end

    def multiword_change?
      @rm.include?(' ') or @add.include?(' ')
    end
  
    def empty_change?
      @type == :insertion or @type == :deletion
    end

    def unknown_morph?
      @rm_morph.nil? or @add_morph.nil?
    end

    def longer_word_is_shorter_than?(number)
      [@rm.size, @add.size].max < number
    end

    def vandalism_change? 
      @type == :vandalism 
    end

    def unknown_change? 
      @type == :unknown 
    end
    
    def non_word_change? 
      @type == :nonword 
    end

    def real_word_change? 
      @type == :realword 
    end

  end
end
