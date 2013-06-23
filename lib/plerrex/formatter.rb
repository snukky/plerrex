require 'plerrex/edited_text'

require 'yaml'
require 'colorize'

module Plerrex
  class Formatter

    COMMENT = '#'
    ERROR_SEPARATOR = '->'
    VALUE_SEPARATOR = ';'
    VALUE_INDENT = '>'

    def initialize
    end

    def format(edited_texts)
      edited_texts.to_yaml
    end

    def deformat(text)
      YAML.load_documents(text)
    end

    def print(edited_texts, options={})
      color = options[:color] || false
      edited_texts.map { |err| print_one(err, color) }
    end
  
    private

    def print_one(edited_text, color)
      error_list = []

      if color
        splitted_old = edited_text.text.split
        splitted_new = edited_text.new_text.split
      end

      edited_text.errors.each do |error|
        if color
          fragment_old = splitted_old[(error.position)..-1]
          fragment_new = splitted_new[(error.position)..-1]
        
          unless fragment_old.nil?
            splitted_old = splitted_old[0...(error.position)] + fragment_old.join(' ').
              sub(error.error, error.error.light_red).split
          end

          unless fragment_new.nil?
            splitted_new = splitted_new[0...(error.position)] + fragment_new.join(' ').
              sub(error.correction, error.correction.light_green).split
          end
        end

        error_list << print_error(error, color)
      end

      result = if color 
                 splitted_old.join(' ') + "\n" + splitted_new.join(' ')
               else
                 edited_text.text + "\n" + edited_text.new_text
               end

      return result + "\n" + error_list.join("\n") + "\n"
    end

    def print_error(error, color)
      (color ? '  ' : "#{VALUE_INDENT} ") + 
        "#{color ? error.error.red : error.error} #{ERROR_SEPARATOR} " + 
        "#{color ? error.correction.green : error.correction} " +
        "[#{error.position}#{VALUE_SEPARATOR}" +
          error.attributes.map{ |attr, val| "#{color ? val.to_s.blue : val}" }.
            reverse.join(VALUE_SEPARATOR) + 
        "]"
    end

  end
end
