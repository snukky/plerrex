module Plerrex
  class EditedText

    attr_reader :text, :new_text, :errors
    attr_accessor :attributes

    def initialize(text, new_text=nil, error_corrections=[], attributes={})
      @text = text
      @new_text = new_text
      @attributes = attributes

      raise ArgumentError, 
            "Third parameter should be an Array and contains only" \
            " ErrorCorrection objects" \
        unless only_error_correction_objects?(error_corrections)

      @errors = error_corrections 
    end

    def print
      puts Formatter.new.printable([self], :error_list => true)
    end

    def reverse?(erroneus_text)
      @text == erroneus_text.new_text and @new_text == erroneus_text.text
    end

    def include?(error, correction, no_types=[])
      @errors.any? do |err| 
        err.error == error and err.correction == correction \
          and !no_types.include?(err.category)
      end
    end
    
    def add_error(error)
      @errors << error
    end
  
    private
  
    def only_error_correction_objects?(errors)
      return false unless errors.kind_of?(Array)
      errors.all? { |err| err.kind_of? ErrorCorrection }
    end

  end
end
