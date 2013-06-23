#encoding:utf-8

require 'spec_helper'
require 'awesome_print'

describe Plerrex::Validator do
  before :all do
    @detector = Plerrex::Detector.new
    @validator = Plerrex::Validator.new
  end
 
  describe '#wiki_artifact?' do
    it 'should detect enumerations' do
      @validator.wiki_artifact?(
          'Białe Błota, Brzoza, Osielsko, Sicienko.')
        .should be_true

      @validator.wiki_artifact?(
          'Wyliczanka *Ala *ma lub miała * kota i psa')
        .should be_true

      @validator.wiki_artifact?(
          'Wyliczanka -- Ala -- ma lub miała -- kota i psa')
        .should be_true

      @validator.wiki_artifact?(
          "Ezoteryczne InterCal • Brainfuck • Befunge • Malbolge • Whitespace" \
          " • False • HQ9+ • Shakespeare")
        .should be_true

      @validator.wiki_artifact?(
          "STDIN – Std Input STDERR – Std Error STDOUT – Standard Output")
        .should be_true

      @validator.wiki_artifact?(
          "Zuch - Harcerz - Harcerz Starszy - Wędrownik - Instruktor Zuchy, Harcerze")
        .should be_true

      @validator.wiki_artifact?(
          "liście naprzemnianległe, błyszczące, pojedyncze, o pofałdowanym" \
          " brzegu; mają ogonek, osiągają długość do 35 cm")
        .should be_false
    end

    it 'should detect invalid encodings' do
      @validator.wiki_artifact?(
          "Alicj?, mia?a kota zjad? pies.")
        .should be_true

      @validator.wiki_artifact?(
          "Alicj?, miała? ?kota zjad? pies.")
        .should be_false
    end

    it 'should detect words including capital letter at wrong position' do
      @validator.wiki_artifact?(
          "NazwaWymowaWygląd - mała literaWygląd - duża literaEncje HTML")
        .should be_true
    end

    it 'should detect language links' do
      @validator.wiki_artifact?(
          "en:Bartolomeo Ammanati fr:Bartolomeo Ammanati")
        .should be_true
    end

    it 'should detect wiki-specified links' do
      @validator.wiki_artifact?(
          "Zobacz też: podstawowe zagadnienia z matematyki")
        .should be_true

      @validator.wiki_artifact?(
          "plik:ala ma kota")
        .should be_true

      @validator.wiki_artifact?(
          "Komentarz: ala ma kota")
        .should be_true

      @validator.wiki_artifact?(
          "Linki zewnętrzne - ala ma kota")
        .should be_true
    end

    it 'should detect redundant table elements' do
      @validator.wiki_artifact?(
          "imię=Zofia |nazwisko= Radwańska-Paryska |imię2=Witold Henryk" \
          " |nazwisko2= tytuł= Wielka Encyklopedia miejsce=wydawca= Wyd.")
        .should be_true
    end

    it 'should detect other wiki artifacts' do
      @validator.wiki_artifact?("Jednostki miar i wag|*").should be_true 
      @validator.wiki_artifact?("REDIRECT Kościół w RP").should be_true
    end

    it 'should not detect single hyphens as invalid' do
      @validator.wiki_artifact?(
          "Obszary te zamieszkuje 293 - 418 tys (w zależności przyjętego od" \
          " kryterium narodowego - czytaj niżej) Komiaków, posługujących się" \
          " głównie językiem komi, rzadziej rosyjskim.")
        .should be_false
    end
  end

  describe '#valid_sentence?' do
    it 'should accept valid sentences' do
      @validator.valid_sentence?("Ala ma kota.").should be_true
      @validator.valid_sentence?("'Mam kota' powiedziała Ala.").should be_true
      @validator.valid_sentence?("13 kotów to za dużo dla Ali?").should be_true
      @validator.valid_sentence?("Ów kot jest Ali!").should be_true
      @validator.valid_sentence?("Ala ma dużo zwierząt, np.:").should be_true
      @validator.valid_sentence?("123 koty; 23 psy; 3 małpy;").should be_true
    end

    it 'should reject invalid sentences' do
      @validator.valid_sentence?("Ala ma kota").should be_false
      @validator.valid_sentence?("ala ma kota.").should be_false
      @validator.valid_sentence?("'mam kota' powiedziała :)").should be_false
      @validator.valid_sentence?("13 kotów, 7 psów i 2 małpy").should be_false
    end

    it 'should reject sentence with too few words' do
      @validator.valid_sentence?("1948 : Briek Schotte BEL").should be_false
      @validator.valid_sentence?(
          "Собрание сочинений 1989 — 1997 / Sobranie sochineniy 1989 - 1997 (1997).")
        .should be_false
    end

    it 'should reject sentences with unpaired brackets' do
      @validator.valid_sentence?("Ala ma kota i psa (bardzo").should be_false
      @validator.valid_sentence?("Ala ma kota i psa (b.").should be_false
      @validator.valid_sentence?("Ala kota] i psa!").should be_false
    end
  end

  describe '#valid_error? (enumeration)' do
    it 'should recognize insertion/deletion at the end of the sentence' do
      errors = @detector.find("Pozostałe oznaczenia w tekście.", 
                              "Pozostałe oznaczenia w tekście")
      @validator.valid_error?(errors.first).should be_false

      errors = @detector.find(
        "Najbardziej znane przykłady zastosowania tej techniki:",
        "Najbardziej znane przykłady zastosowania tej techniki")
      @validator.valid_error?(errors.first).should be_false

      errors = @detector.find(
        "Koncert trwał ponad trzy godziny i w całości był transmitowany przez Trójkę..",
        "Koncert trwał ponad trzy godziny i w całości był transmitowany przez Trójkę.")
      @validator.valid_error?(errors.first).should be_true
    end

    it 'should recognize list with brackets' do
      errors = @detector.find("Lit (pierwiastek) Lit (waluta)", 
                              "lit (pierwiastek) lit (waluta)")
      @validator.valid_error?(errors.first).should be_false

      errors = @detector.find("Parówka (wędlina) Parówka (zabieg kosmetyczny)", 
                              "parówka (wędlina) parówka (zabieg kosmetyczny)")
      @validator.valid_error?(errors.first).should be_false
    end          
  end

  describe '#valid_error? (wiki)' do
    it 'should recognize merged lists' do
      errors = @detector.find(
        "Politycy Zawadzki Sylwester Posłowie na Sejm Zawadzki Sylwester" \
        " Polscy Zawadzki Sylwester",
        "Politycy Zawadzki, Sylwester Posłowie na Sejm Zawadzki, Sylwester" \
        " Polscy Zawadzki, Sylwester")
      @validator.valid_error?(errors.first).should be_false

      errors = @detector.find(
        "Serbscy Jugović, Vladimir Piłka Crveny Zvezdy Jugović, Vladimir", 
        "Serbscy Jugović, Vladimir Piłka Crvenej Zvezdy Jugović, Vladimir")
      @validator.valid_error?(errors.first).should be_false

      errors = @detector.find(
        "Ustrój polityczny Tuwalu Ustrój polityczny Wanuatu",
        "Ustrój polityczny Tuvalu Ustrój polityczny Vanuatu")
      @validator.valid_error?(errors.first).should be_false
    end
  end
end  
