# encoding: utf-8

Gem::Specification.new do |s|
  s.name        = "gem-dependencies"
  s.version     = "0.2.2"
  s.summary     = "RubyGems plugin to simplify installing binary gems on runtime systems."
  s.description = "This gem makes it easy to install binary gems on systems without a compiler."
  s.homepage    = "https://github.com/shreeve/gem-dependencies"
  s.authors     = ["Steve Shreeve"]
  s.email       = "steve.shreeve@gmail.com"
  s.license     = "MIT"
  s.files       = `git ls-files`.split("\n") - %w[.gitignore]
  s.cert_chain  = ["certs/shreeve.pem"]
  s.signing_key = File.expand_path("~/.ssh/gem-private_key.pem") if $0 =~ /gem\z/
end
