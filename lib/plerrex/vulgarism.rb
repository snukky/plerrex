module Plerrex
  module Vulgarism 
  
    FILE_PATH = File.join(File.dirname(__FILE__), 'data', 'wulgaryzmy.txt')
    LIST = File.readlines(FILE_PATH).map { |v| v.chomp }.uniq

    def self.vulgarism?(word)
      LIST.include?(word)  
    end

    def self.vulgarism_any_of?(*words)
      !(LIST & words).empty?
    end

  end
end
