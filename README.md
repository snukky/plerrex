# PlErrEx

Gem for automatic extraction of various kinds of errors such as spelling, 
typographical, grammatical, syntactic, semantic, and stylistic ones from text 
edition history.
Current implementation handles only texts composed in Polish language.

## Installation

Add this line to your application's Gemfile:

    gem 'plerrex'

And then execute:

    $ bundle

## Usage

See test and binary files.

Using command-line script:

    plerrex "ala ma koeta i psa" "Ala ma kota i psa."
  
Gives a result:

    ala ma koeta i psa
    Ala ma kota i psa.
      ala -> Ala [0;wielkość liter;1;nonword]
      koeta -> kota [2;pisownia;1;nonword]
      psa -> psa. [4;interpunkcja]

