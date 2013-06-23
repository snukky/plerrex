module Plerrex
  class ErrorCorrection

    attr_reader :error, :correction, :position
    attr_accessor :attributes

    def initialize(error, correction, position=0, attributes={})
      @error = error
      @correction = correction
      @position = position
      @attributes = attributes
    end

    def category
      @attributes[:category]
    end

  end
end
