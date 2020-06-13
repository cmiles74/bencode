(declare-project
 :name "bencode"
 :description "A bencode library for Janet"
 :author "Christopher Miles <twitch@nervestaple.com>"
 :license "MIT"
 :url "https://github.com/cmiles74/bencode"
 :repo "git+https://github.com/cmiles74/bencode.git"
 :dependencies ["https://github.com/joy-framework/tester"])

(declare-source
 :source @["src/bencode.janet"])
