$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'plerrex'
require 'rspec-expectations'

include Plerrex

RSpec::Matchers.define :be_error_type_of do |expected|
  match do |actual|
    actual[0] == Recognizer::ERRORS[expected]
  end

  failure_message_for_should do |actual|
    "expected that #{actual} would be an error type of #{Recognizer::ERRORS[expected]}"
  end

  failure_message_for_should_not do |actual|
    "expected that #{actual} would not be an error type of #{Recognizer::ERRORS[expected]}"
  end

  description do
    "be an error type of #{Recognizer::ERRORS[expected]}"
  end
end

RSpec::Matchers.define :be_rejected_error do 
  match do |actual|
    actual[0] == Recognizer::REJECTED_ERROR
  end

  failure_message_for_should do |actual|
    "expected that #{actual} would be rejected"
  end

  failure_message_for_should_not do |actual|
    "expected that #{actual} would not be rejected"
  end

  description do
    "be rejected"
  end
end
