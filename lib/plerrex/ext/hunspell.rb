require 'hunspell-ffi'
require 'iconv' if RUBY_VERSION < '1.9'

class Hunspell
  
  ENCODING_ISO = 'ISO-8859-2'
	ENCODING_UTF = 'UTF-8'

  alias_method :old_suggest, :suggest

  def suggest(word)
    self.send(:old_suggest, decode_utf8(word)).map { |sug| encode_utf8(sug) }
  end

  alias_method :old_check, :check

  def check(word)
    self.send(:old_check, decode_utf8(word))
  end

  private

  def decode_utf8(str)
    return Iconv.iconv(ENCODING_ISO, ENCODING_UTF, str).first if RUBY_VERSION < '1.9'
    str.dup.encode! ENCODING_ISO
  end

  def encode_utf8(str)
    return Iconv.iconv(ENCODING_UTF, ENCODING_ISO, str).first if RUBY_VERSION < '1.9'
    str.force_encoding ENCODING_ISO
    str.encode! ENCODING_UTF
  end

end
