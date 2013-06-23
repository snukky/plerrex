#encoding:utf-8

require 'spec_helper'

describe Hunspell do
  before :all do
    @hunspell = Hunspell.new('/usr/share/hunspell', 'pl_PL')
  end
  
  it 'should work with UTF-8 encoding' do
    @hunspell.check("słowo").should be_true
    @hunspell.suggest("slowo").should include("słowo")
  end
end
