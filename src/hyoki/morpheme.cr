require "fucoidan"
require "./document/line"

module Hyoki
  struct Morpheme
    struct Feature
      @part_of_speech : String
      @part_of_speech_subcategory1 : String
      @part_of_speech_subcategory2 : String
      @part_of_speech_subcategory3 : String
      @conjugation : String
      @conjugation_form : String
      @lexical_form : String
      @yomi : String
      @pronunciation : String

      def initialize(feature_csv)
        values = feature_csv.split(",")
        if values.size < 9
          # pad values to avoid IndexError
          (9 - values.size).times { values << "*" }
        end
        @part_of_speech = values[0]
        @part_of_speech_subcategory1 = values[1]
        @part_of_speech_subcategory2 = values[2]
        @part_of_speech_subcategory3 = values[3]
        @conjugation = values[4]
        @conjugation_form = values[5]
        @lexical_form = values[6]
        @yomi = values[7]
        @pronunciation = values[8]
      end

      getter :part_of_speech, :part_of_speech_subcategory1,
        :part_of_speech_subcategory2, :part_of_speech_subcategory3,
        :conjugation, :conjugation_form, :lexical_form, :yomi,
        :pronunciation
    end

    @surface : String
    @length : UInt16
    @rlength : UInt16
    @node_id : UInt32
    @rc_attr : UInt16
    @lc_attr : UInt16
    @posid : UInt16
    @char_type : UInt8
    @stat : UInt8
    @isbest : Bool
    @alpha : Float32
    @beta : Float32
    @prob : Float32
    @wcost : Int16
    @cost : Int64
    @index : Int32
    @max_index : Int32
    @source_string : String
    @line : Document::Line
    @index_in_source_string : Int32

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

    def initialize(node, index, max_index, source_string, line)
      @surface = node.surface
      @feature = Feature.new(node.feature)
      @length = node.length
      @rlength = node.rlength
      @node_id = node.id
      @rc_attr = node.rcAttr
      @lc_attr = node.lcAttr
      @posid = node.posid
      @char_type = node.char_type
      @stat = node.stat
      @isbest = node.isbest
      @alpha = node.alpha
      @beta = node.beta
      @prob = node.prob
      @wcost = node.wcost
      @cost = node.cost
      @index = index
      @max_index = max_index
      @source_string = source_string
      @line = line
      @index_in_source_string = -100 # FIXME: kludge to pass typechecking
    end

    getter :surface, :feature, :length, :rlength, :node_id, :rc_attr,
      :lc_attr, :posid, :char_type, :stat, :isbest, :alpha, :beta, :prob,
      :wcost, :cost, :index, :source_string, :line

    def index_in_source_string
      if @index_in_source_string >= 0 # FIXME: kludge to pass typechecking
        @index_in_source_string
      else
        indexes = @line.surface_indexes(@surface)
        source_length = @source_string.size
        # add 0.01 to avoid divide-by-zero error
        index_proportions = indexes.map { |i| (i.to_f / source_length) + 0.01 }
        morpheme_index_proportion = (@index.to_f / @max_index) + 0.01
        index_candidates =
          indexes.zip(index_proportions).sort_by do |_i, i_proportion|
            (i_proportion / morpheme_index_proportion - 1.0).abs
          end
        @index_in_source_string = index_candidates.first.first # best guess
      end
    end
  end
end
