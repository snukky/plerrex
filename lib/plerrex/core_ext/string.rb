require 'polish_chars'

class String
  def start_with_big_letter?
    return false if self.empty?
    self[0].upcase == self[0]
  end
end
