#encoding:utf-8

require 'set'

module Plerrex
  class Thesaurus
 
    DEFAULT_PATH = File.join(File.dirname(__FILE__), 'data', 'thesaurus.txt')
    COMMENT_SIGN = '#'
    WORD_SEPARATOR = ';'

    def initialize(path=nil)
      @path = path || DEFAULT_PATH
      @thesaurus = File.readlines(@path)
                     .delete_if { |line| line.start_with? COMMENT_SIGN }
                     .map { |line| line.chomp }.to_set
    end

    def the_same_synset?(word_1, word_2)
      synsets_1 = raw_synsets(word_1)
      synsets_2 = raw_synsets(word_2)

      !(synsets_1 & synsets_2).empty?
    end

    def synets(word)
      raw_synsets(word).map { |syn| syn.split(WORD_SEPARATOR) }
    end

    private

    def raw_synsets(word)
      @thesaurus.grep(/(^|#{WORD_SEPARATOR})#{word}(#{WORD_SEPARATOR}|$)/)
    end
  
  end
end
