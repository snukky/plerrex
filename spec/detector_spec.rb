#encoding:utf-8

require 'spec_helper'

describe Plerrex::Detector do
  before :all do
    @detector = Plerrex::Detector.new
  end

  describe 'rejected' do
    it 'should not check sentence marked as wiki artifact' do
      @detector.find(
          "Zobacz też Białe Błota, Brzoza, Niemcz, Osielsko, Sicienko",
          "Zobacz też: Białe Błota, Brzoza, Niemcz, Osielsko, Sicienko.")
        .should be_empty

      @detector.find(
          "Ala, ma, ktoa psa, i, cos, tam jeszcze", 
          "Ala, ma, kota psa, i, coś, tam jeszcze")
        .should be_empty

      @detector.find(
          "Alicj?, mia?a kota zjad? pies.", 
          "Alicj?, kt?ra mia?a kota zjad? pies.")
        .should be_empty

      @detector.find(
          "NazwaWymowaWygląd - mała literaWygląd - duża literaEncje HTML",
          "NazwaWymowaWygląd - mała literaWygląd - wielka literaEncje HTML")
        .should be_empty

      @detector.find(
          "Ezoteryczne  InterCal • Brainfuck • Befunge • Unlambda • Malbolge" \
          " • Whitespace  • False • HQ9+  • Shakespeare",
          "Ezoteryczne  InterCal • Brainfuck • BeFunge • Unlambda • Malbolge" \
          " • Whitespace  • False • HQ9+  • Shakespeare")
        .should be_empty

      @detector.find(
          "imię=Zofia |nazwisko= Radwańska-Paryska |imię2=Witold Henryk" \
          " |nazwisko2= tytuł= Wielka Encyklopedia miejsce=wydawca= Wyd.",
          "imię=Zofia |nazwisko= Radwańska-Paryska |imię2=Witold Henryk" \
          " |nazwisko2= tytuł= Wielka encyklopedia miejsce=wydawca= Wyd.")
        .should be_empty
    end

    it 'should not accept obvious mistakes' do
      @detector.find(
          "Kto może łapać na spining", 
          "Kto może łapać na spining??")
        .should be_empty
    end

    it 'should not accept inflection changes if there are rejected errors' do
      @detector.find(
          "Arytmetyka (z greckiego αριθμός = liczba) jest najstarszą i" \
          " najbardziej podstawową gałęzią matematyki, używaną powszechnie do" \
          " rozmaitych zadań od zwykłego liczenia do zaawansowanych obliczeń" \
          " naukowych i finansowych.",
          "Arytmetyka (z greckiego αριθμός = liczba) - najstarsza i" \
          " najbardziej podstawowa gałąź matematyki, używana powszechnie do" \
          " rozmaitych zadań od zwykłego liczenia do zaawansowanych obliczeń" \
          " naukowych i finansowych.")
        .should be_empty
    end

    it 'should reject sentences with too large length difference' do
      @detector.find(
          "Zamek wybudowany w I poł. XVI wieku przez Mikołaja Firleja i jego" \
          " syna – Piotra Firleja.",
          " zamek wybudowany w I poł. XVI wieku przez Mikołaja Firleja i jego" \
          " syna – Piotra Firleja, oddział Muzeum Nadwiślańskiego w" \
          "Kazimierzu Dolnym kościół wybudowany ok. 1350 roku w stylu" \
          " gotyckim, znacznie przebudowany w XVI wieku w stylu renesansowym," \
          " wewnątrz nagrobek Firlejów dłuta Santi Gucciego z Florencji" \
          " zespół dworski złożony budynków przeniesionych z pobliskich" \
          " terenów Lubelszczyzny.")
        .should be_empty
    end
  end

  describe 'accepted' do
    it 'should accept multiword changes with small edit distance' do
      edited_texts = @detector.find(
          "Kontrolki ActiveX mają swój początek w komponentach VBX, na bazie" \
          " krórych stworzony kontrolki OCX, nazwane później jako ActiveX.",
          "Kontrolki ActiveX mają swój początek w komponentach VBX, na bazie" \
          " których stworzono kontrolki OCX, nazwane później jako ActiveX.")
      
      error = "krórych stworzony" 
      correction = "których stworzono"
      forbidden_types = [Recognizer::REJECTED_ERROR]
      
      result = edited_texts.any? do |edited_text| 
        edited_text.include?(error, correction, forbidden_types)
      end

      result.should be_true
    end

    it 'should join splitted sentences' do
      expected_result = @detector.find("Ala ma ktoa i psa.", "Ala ma kota i psa.")
      result = @detector.find("Ala ma ktoa\ni psa.", "Ala ma kota \n i psa.")

      result.first.text.should eql expected_result.first.text
      result.first.new_text.should eql expected_result.first.new_text
    end

    it 'should found errors in bad-formed sentence' do
      @detector.find(
          "Atomy o takiej samej liczbie protonów w jądrze należą do tego" \
          " samego pierwiastka chemicznego",
          "Atomy o takiej samej liczbie protonów w jądrze należą do tego" \
          " samego pierwiastka chemicznego.")
        .should_not be_empty

      @detector.find("Ala ma ktoa i psa", "Ala ma kota i psa.")
        .should_not be_empty
    end

    it 'should not recognize "ku" as change in age notation' do
      result = @detector.find("Libido jestodmianą woli mocy.",
                              "Libido jestodmianą woli ku mocy.")
      result.size.should eql 1
      result.first.errors.first.category.should_not eql 'wiek'
    end

    it 'should recognize these instances' do
      result = @detector.find(
        "Zmienne AWK są dynamiczne: zaczynają istnieć gdy są po raz pierwszy użyte.",
        "Zmienne AWK są dynamiczne — zaczynają istnieć, gdy są po raz pierwszy użyte.")

      result.size.should eql 1
      result.first.errors.first.category.should eql 'interpunkcja'
    end
  end

end
