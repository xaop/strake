require 'rubygems'
require 'rake/gempackagetask'

STRAKE_VERSION = File.read("VERSION")[/[\d.]*/]

desc "Build a gem"
spec = Gem::Specification.new do |s|
  s.name = "strake"
  s.version = STRAKE_VERSION
  s.author = "Peter Vanbroekhoven"
  s.email = "peter@xaop.com"
  s.summary = "A Simple Transactional rake task runner"
  s.description = s.summary
  s.files += %w[VERSION Rakefile]
  s.files += Dir['lib/**/*.rb'] + Dir['bin/**/*'] + Dir['lib/**/*.rake']
  s.bindir = "bin"
  s.executables.push(*Dir['bin/*'].map { |f| File.basename(f) })
  s.require_path = 'lib'
  s.required_ruby_version = '>= 1.8.0'
  s.platform = Gem::Platform::RUBY
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end
