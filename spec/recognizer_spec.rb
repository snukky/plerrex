#encoding:utf-8

require 'spec_helper'

describe Plerrex::Recognizer do
  before :all do
    @recognizer = Plerrex::Recognizer.new
  end

  describe 'simple' do
    it 'should categorize change within spaces' do
      @recognizer.recognize("białoczerwony", "biało-czerwony").should be_error_type_of :space
      @recognizer.recognize("istnieć", "istnieć,").should be_error_type_of :punct
      @recognizer.recognize("tys", "tys.").should be_error_type_of :punct
    end
  end

  describe 'inflection' do
    it 'should accept inflection change with punctuations' do
      @recognizer.recognize("wzbudzony,", "wzbudzonym,").should be_error_type_of :infl
    end

    it 'should accept multiword inflection change' do
      @recognizer.recognize("wysokie średnie", "wysoką średnią").should be_error_type_of :infl
    end

    it 'should accept inflection change regardless of prepositions' do
      @recognizer.recognize("przez system", "w systemie").should be_error_type_of :infl
    end

    it 'should recognize inflection tense change' do
      @recognizer.recognize("jest", "był").should be_error_type_of :infl_ten
      @recognizer.recognize("twierdził", "twierdzi").should be_error_type_of :infl_ten
      @recognizer.recognize("pamięta", "pamiętał").should be_error_type_of :infl_ten
    end

    it 'should recognize inflection number change' do
      @recognizer.recognize("fal", "fali").should be_error_type_of :infl_nb
      @recognizer.recognize("Temperatura", "Temperatury").should be_error_type_of :infl_nb
    end
  end

  describe 'grammatical' do 
    it 'should recognize change in verb aspect' do
      @recognizer.recognize("koronował", "ukoronował").should be_error_type_of :sem_asp
    end

    it 'should recognize change in verb aspect and tense' do
      @recognizer.recognize("zostają", "zostały").should be_error_type_of :sem_asp
      @recognizer.recognize("podpisuje", "podpisał").should be_error_type_of :sem_asp
      @recognizer.recognize("wynosi", "wyniesie").should be_error_type_of :sem_asp
    end

    it 'should recognize change in adjective degree' do
      @recognizer.recognize("większych", "największych").should be_error_type_of :sem_deg
    end

    it 'should recognize semantic change between synonyms' do
      @recognizer.recognize("dżudo", "judo").should be_error_type_of :sem_style
    end
  end

  describe 'spellcheck' do
    it 'should accept typical spell error' do
      @recognizer.recognize("nnych", "innych").should be_error_type_of :spell
      @recognizer.recognize("słwo", "słowo").should be_error_type_of :spell
    end

    it 'should not accept multiple words change' do
      @recognizer.recognize("i nnych", "innych").should_not be_error_type_of :spell
    end

    it 'should not accept change from/to empty string' do
      @recognizer.recognize("", "innych").should_not be_error_type_of :spell
    end

    it 'should accept probable spellings' do
      @recognizer.recognize("pozwalaja", "pozwala").should be_error_type_of :spell_xxx
      @recognizer.recognize("swiadzca", "świadczą").should be_error_type_of :spell_xxx
    end

    it 'should not recognize words with punctuations in the middle of string' do
      @recognizer.recognize("m.im.", "m.in.").should_not be_rejected_error
    end

    it 'should recognizer contextual change in diacritics signs' do
      @recognizer.recognize('Alicje', 'Alicję').should be_error_type_of :diac_real
    end
  end

  describe 'categories' do
    it 'should recognize change within conjunctions' do
      @recognizer.recognize("", "albo").should be_error_type_of :conj
      @recognizer.recognize("lub", "").should be_error_type_of :conj
      @recognizer.recognize("lub", "albo").should be_error_type_of :conj
    end

    it 'should recognize change within prepositions' do
      @recognizer.recognize("", "z").should be_error_type_of :prep
      @recognizer.recognize("w", "").should be_error_type_of :prep
      @recognizer.recognize("w", "z").should be_error_type_of :prep
    end

    it 'should reject partly change' do
      @recognizer.recognize("przez", "opisywały").should_not be_error_type_of :prep
    end
  end

  describe 'frequent' do
    it 'should recognize change between countable and uncountable quantifiers' do
      @recognizer.recognize("ilości", "liczbie").should be_error_type_of :count
    end

    it 'should recognize change in year notation' do
      @recognizer.recognize("roku", "r.").should be_error_type_of :year
    end

    it 'should recognize change in age notation' do
      @recognizer.recognize("w.", "wieku").should be_error_type_of :age
    end

    it 'should recognize abbreviation change' do
      @recognizer.recognize("Śl.", "Śląski").should be_error_type_of :abbr
      @recognizer.recognize("osiedle", "os.").should be_error_type_of :abbr
      @recognizer.recognize("wg", "według").should be_error_type_of :abbr
      @recognizer.recognize("mln.", "miliona.").should be_error_type_of :abbr
      @recognizer.recognize("b", "były").should be_error_type_of :abbr
    end
  end

  describe 'style' do
    it 'should accept style errors' do
      @recognizer.recognize("także", "też").should be_error_type_of :sem_style
    end

    it 'should accept camelize style errors' do
      @recognizer.recognize("Idea", "Pomysł").should be_error_type_of :style
    end

    it 'should accept style errors with punctuations' do
      @recognizer.recognize("moc,", "siłę,").should be_error_type_of :style
    end

    it 'should accept multiword unknown change' do
      @recognizer.recognize("krótych średnia", "których średnią").should be_error_type_of :unknown
    end
  end

  describe 'rejected' do
    it 'should reject vulgarisms' do
      @recognizer.recognize("materię", "gówno").should be_rejected_error
      @recognizer.recognize("", "jakieś gówno").should be_rejected_error

      @recognizer.recognize("", "GóWnO").should be_rejected_error
    end

    it 'should reject uppercase changes' do
      @recognizer.recognize("olefiny", "LULKENY").should be_rejected_error
      @recognizer.recognize("LULKENY", "olfeiny").should be_rejected_error
      @recognizer.recognize("ala ma kota", "AlA mA kOtA").should be_rejected_error
    end

    it 'should reject strings with misused punctuaction' do
      @recognizer.recognize(";DDD", "").should be_rejected_error
      @recognizer.recognize(".NET", ".NET,").should be_rejected_error
      @recognizer.recognize("brutus", "brutus,-").should be_rejected_error
      @recognizer.recognize("zrobił", "zrobił-").should be_rejected_error
      @recognizer.recognize("regulae", "regula---e").should be_rejected_error
      @recognizer.recognize("co", "co??").should be_rejected_error
      @recognizer.recognize("biało-czarny", "biało--czarny").should be_rejected_error
      @recognizer.recognize("serdecznie.--siwulek", "serdecznie.siwulek").should be_rejected_error
      @recognizer.recognize("koniec.", "koniec..").should be_rejected_error
    end

    it 'should reject wrong corrections' do
      @recognizer.recognize("największy", "najwiekszy").should be_rejected_error
    end
  end

end
