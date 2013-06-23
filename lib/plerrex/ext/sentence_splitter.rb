require 'srx/polish/sentence_splitter'

class SRX::Polish::SentenceSplitter
  
  def sentences(safe_mode=true)
    sentences = []

    if safe_mode
      begin
        each { |sentence| sentences << sentence }
      rescue
      ensure
        sentences ||= [@input.to_s]
      end
    else
      each { |sentence| sentences << sentences }
    end

    return sentences
  end

end
