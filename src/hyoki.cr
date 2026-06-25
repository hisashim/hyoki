require "option_parser"
require "./hyoki/morpheme"
require "./hyoki/document"
require "./hyoki/cli"
require "./hyoki/version"

module Hyoki
  def self.string_indexes(string, substring)
    string.scan(Regex.new(Regex.escape(substring))).map(&.begin)
  end

  def self.string_to_morphemes(string, line, parser)
    # Note: Avoid method chaining to Fucoidan constructor,
    # e.g. `Fucoidan::Fucoidan.new.enum_parse(...)`, as you may
    # encounter errors such as `Invalid memory access (signal 11)` or
    # `free(): invalid pointer` at runtime somehow.
    morphemes = parser.enum_parse(string).to_a.reject! do |n|
      n.feature.starts_with? "BOS/EOS" # remove BOS/EOS nodes
    end
    return [] of Morpheme if morphemes.empty?
    max_index = morphemes.size - 1
    morphemes.map_with_index do |n, i|
      Morpheme.new(node: n,
        index: i,
        max_index: max_index,
        source_string: string,
        line: line)
    end
  end

  def self.yomi(string, yomi_parser)
    yomi_parser.parse(string).chomp
  end
end
