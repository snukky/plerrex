#!/usr/bin/env rake

require "rspec/core/rake_task"

desc "Run the specs under spec/"
RSpec::Core::RakeTask.new :test do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rspec_opts = ['--color']
end

desc "Build current version of gem"
task :build do
  system "gem build plerrex.gemspec"
end

desc "Install gem on local machine"
task :install do
  gem_file = Dir.glob('./plerrex-*.*.*.gem').sort.last
  system "gem install #{gem_file} --no-rdoc --no-ri"
end
