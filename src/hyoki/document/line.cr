require "../morpheme"

module Hyoki
  struct Document
    struct Line
      LINE_REGEX =
        /([^\r\n]*?)(\r\n|\r|\n)|(.+)/

      @source_string : String
      @body : String
      @eol : String?
      @index : Int32
      @morphemes : Array(Morpheme)?
      @surface_indexes : Hash(String, Array(Int32))
      @parser : Fucoidan::Fucoidan
      @source_name : String?

      def self.string_indexes(string, substring)
        string.scan(Regex.new(Regex.escape(substring))).map(&.begin)
      end

      private def line_to_morphemes(line, parser)
        # Note: Avoid method chaining to Fucoidan constructor,
        # e.g. `Fucoidan::Fucoidan.new.enum_parse(...)`, as you may
        # encounter errors such as `Invalid memory access (signal 11)` or
        # `free(): invalid pointer` at runtime somehow.
        raw_morphemes = parser.enum_parse(line.body).to_a.reject! do |n|
          n.feature.starts_with? "BOS/EOS" # remove BOS/EOS nodes
        end
        return [] of Morpheme if raw_morphemes.empty?
        max_index = raw_morphemes.size - 1
        source_string = line.body
        raw_morphemes.map_with_index do |n, i|
          Morpheme.new(node: n,
            index: i,
            max_index: max_index,
            source_string: source_string,
            line: line)
        end
      end

      def initialize(source_string, index, parser, source_io = nil)
        mds = source_string.scan(LINE_REGEX)
        raise <<-EOS if mds.size != 1
          LINE_REGEX failed to produce just 1 match (#{mds.inspect})
          EOS
        md = mds.first
        body, eol =
          case
          when md[3]? then {md[3], nil}
          when md[1]? then {md[1], md[2]}
          else             {md[1], md[2]}
          end
        @source_string = source_string
        @body = body
        @eol = eol
        @index = index
        @morphemes = nil
        @surface_indexes = Hash(String, Array(Int32)).new
        @parser = parser
        @source_name =
          if source_io.responds_to?(:path)
            source_io.path
          end
      end

      getter :body, :eol, :index, :source_name

      def morphemes
        @morphemes ||= line_to_morphemes(self, @parser)
      end

      def surface_indexes(surface)
        if indexes = @surface_indexes[surface]?
          indexes
        else
          @surface_indexes[surface] = Line.string_indexes(@source_string, surface)
        end
      end
    end
  end
end
