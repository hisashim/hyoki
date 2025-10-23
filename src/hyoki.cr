require "fucoidan"
require "option_parser"

module Hyoki
  VERSION = "0.5.0"

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
        if (size = values.size) < 9
          # pad values to avoid IndexError
          (9 - size).times do
            values << "*"
          end
        else
          values
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
          indexes.zip(index_proportions).sort_by { |_i, i_proportion|
            (i_proportion / morpheme_index_proportion - 1.0).abs
          }
        @index_in_source_string = index_candidates.first.first # best guess
      end
    end
  end

  def self.string_indexes(string, substring)
    string.scan(Regex.new(Regex.escape(substring))).map(&.begin)
  end

  def self.string_to_morphemes(string, line, parser)
    # Note: Avoid method chaining to Fucoidan constructor,
    # e.g. `Fucoidan::Fucoidan.new.enum_parse(...)`, as you may
    # encounter errors such as `Invalid memory access (signal 11)` or
    # `free(): invalid pointer` at runtime somehow.
    morphemes = parser.enum_parse(string).to_a.reject! { |n|
      n.feature.starts_with? "BOS/EOS" # remove BOS/EOS nodes
    }
    return [] of Morpheme if morphemes.empty?
    max_index = morphemes.size - 1
    morphemes.map_with_index { |n, i|
      Morpheme.new(node: n,
        index: i,
        max_index: max_index,
        source_string: string,
        line: line)
    }
  end

  def self.yomi(string, yomi_parser)
    yomi_parser.parse(string).chomp
  end

  struct Document
    LINE_REGEX =
      /([^\r\n]*?)(\r\n|\r|\n)|(.+)/
    ASCII_WORD_REGEX =
      /\A[[:ascii:]]+\z/
    TSV_ESCAPE =
      {"\n" => "\\n", "\t" => "\\t", "\r" => "\\r", "\\" => "\\\\"}
    TSV_ESCAPE_REGEX =
      Regex.new(TSV_ESCAPE.keys.map { |k| "(?:#{Regex.escape(k)})" }.join("|"))
    TSV_HEADER_VARIANTS =
      ["lexical form yomi", "source", "line", "character", "lexical form",
       "surface", "excerpt"].join("\t")
    TSV_HEADER_HETERONYMS =
      ["surface", "source", "line", "character", "yomi", "surface",
       "excerpt"].join("\t")

    alias ReportItem = Tuple(String, Array(Morpheme))
    alias ReportItems = Array(ReportItem)

    enum ReportType
      Variants
      Heteronyms
    end

    enum ReportFormat
      Text
      Markdown
      TSV
    end

    enum SortOrder
      Alphabetical
      Appearance
    end

    struct Line
      @source_string : String
      @body : String
      @eol : String?
      @index : Int32
      @morphemes : Array(Morpheme)?
      @surface_indexes : Hash(String, Array(Int32))
      @parser : Fucoidan::Fucoidan
      @source_name : String?

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
          else
            nil
          end
      end

      getter :body, :eol, :index, :source_name

      def morphemes
        @morphemes ||= Hyoki.string_to_morphemes(body, self, @parser)
      end

      def surface_indexes(surface)
        if indexes = @surface_indexes[surface]?
          indexes
        else
          @surface_indexes[surface] = Hyoki.string_indexes(@source_string, surface)
        end
      end
    end

    @lines : Array(Line)
    @parser : Fucoidan::Fucoidan
    @yomi_parser : Fucoidan::Fucoidan

    def initialize(source_ios : Array(IO), mecab_dict_dir = nil)
      mecab_opts = [] of String
      mecab_opts << "--dicdir=#{mecab_dict_dir}" if mecab_dict_dir
      @parser = Fucoidan::Fucoidan.new(mecab_opts.join(" "))
      @yomi_parser = Fucoidan::Fucoidan.new((mecab_opts + ["-Oyomi"]).join(" "))
      @lines =
        source_ios.reduce([] of Line) { |lines, source_io|
          current_source_lines =
            source_io.gets_to_end.scan(LINE_REGEX).map { |md|
              md[0]
            }.map_with_index { |str, i|
              Line.new(str, i, @parser, source_io: source_io)
            }
          lines.concat(current_source_lines)
        }
    end

    def initialize(string : String, mecab_dict_dir = nil)
      initialize([IO::Memory.new(string)], mecab_dict_dir)
    end

    getter :lines

    # Returns an associative list of yomi (of dictionary form) to
    # variants: words with same pronunciation and different spelling.
    def variants(lines, yomi_parser, sort_order, exclude_ascii_only_items) : ReportItems
      morphemes_by_lexical_form_yomi =
        lines.flat_map(&.morphemes).group_by { |m|
          # Group morphemes by yomi of lexical form.
          #   * When surface and lexical form are the same, yomi of surface
          #     can be used as yomi of lexical form.
          #   * Otherwise (when surface differs from lexical form because of
          #     conjugation and such), we try to guess yomi of lexical form.
          #   * Kludge: For ASCII-only words, we use downcased surface as a
          #     substitute of yomi.
          surface = m.surface
          lexical_form = m.feature.lexical_form
          case
          when surface == lexical_form
            m.feature.yomi
          when ASCII_WORD_REGEX.match surface
            surface.downcase
          else
            Hyoki.yomi(lexical_form, yomi_parser)
          end
        }
      lexical_form_yomi_to_variants =
        morphemes_by_lexical_form_yomi.select { |_lfyomi, morphemes_of_same_lfyomi|
          morphemes_of_same_lfyomi.map { |m|
            surface = m.surface
            if ASCII_WORD_REGEX.match surface
              # Kludge: For ASCII-only words, use surface as a substitute of
              # lexical form.
              surface
            else
              m.feature.lexical_form
            end
          }.uniq!.size >= 2
        }

      # exclude ASCII-only items if specified such.
      if exclude_ascii_only_items == true
        lexical_form_yomi_to_variants.reject! { |key, _morphemes|
          ASCII_WORD_REGEX.match(key)
        }
      end

      case sort_order
      in SortOrder::Alphabetical
        lexical_form_yomi_to_variants.to_a.sort_by { |lfyomi, _morphemes_of_same_lfyomi|
          lfyomi
        }
      in SortOrder::Appearance
        lexical_form_yomi_to_variants.to_a
      end
    end

    # Returns an associative list of surface expression to heteronyms: words
    # with same spelling and different pronunciation.
    def heteronyms(lines, sort_order, exclude_ascii_only_items) : ReportItems
      morphemes_by_surface =
        lines.flat_map(&.morphemes).group_by { |m|
          # group morphemes by surface expression
          m.surface
        }
      surface_to_heteronyms =
        morphemes_by_surface.select { |_surface, morphemes_of_same_surface|
          morphemes_of_same_surface.map(&.feature.yomi).uniq!.size >= 2
        }

      # exclude ASCII-only items if specified such.
      if exclude_ascii_only_items == true
        surface_to_heteronyms.reject! { |key, _morphemes|
          ASCII_WORD_REGEX.match(key)
        }
      end

      case sort_order
      in SortOrder::Alphabetical
        surface_to_heteronyms.to_a.sort_by { |surface, _morphemes_of_same_surface|
          surface
        }
      in SortOrder::Appearance
        surface_to_heteronyms.to_a
      end
    end

    def excerpt(morpheme, context_length, highlight = nil)
      surface = morpheme.surface
      index = morpheme.index_in_source_string
      line_body = morpheme.line.body
      context_length_before, context_length_after =
        case context_length
        in Int32               then {context_length, context_length}
        in Tuple(Int32, Int32) then context_length
        end
      leftmost = index - context_length_before

      if highlight
        prefix =
          if leftmost.negative?
            line_body[0, index]
          else
            line_body[leftmost, context_length_before]
          end
        body = surface
        suffix = line_body[(index + body.size), context_length_after]
        # 1: Bold, 4: Underline, 7: Invert, 0: Reset
        "#{prefix}\e[1;4;7m#{body}\e[0m#{suffix}"
      else
        if leftmost.negative?
          line_body[0, (index + surface.size + context_length_after)]
        else
          line_body[leftmost, (context_length_before + surface.size + context_length_after)]
        end
      end
    end

    def items_to_text(items, excerpt_context_length, highlight, &)
      report_items =
        items.map { |category, relevant_morphemes|
          subcategories = relevant_morphemes.map { |m| yield m }
          item_heading =
            "* #{category}: " +
              subcategories.tally.map { |h, count| "#{h} (#{count})" }.join(" | ")
          subitems =
            relevant_morphemes.map { |m|
              source_name = m.line.source_name
              line_number = m.line.index + 1
              character_number = m.index_in_source_string + 1
              subcategory = yield m
              excerpt = excerpt(m, excerpt_context_length, highlight)
              "  - " +
                [source_name,
                 "L#{line_number}, C#{character_number}",
                 subcategory,
                 excerpt].compact.join("\t")
            }
          [item_heading, subitems.join("\n")].join("\n")
        }
      report_items.join("\n")
    end

    def markup_as_markdown_inline_code(string)
      if string.match(/`/)
        if string.starts_with?("`") || string.ends_with?("`")
          "`` #{string} ``"
        else
          "``#{string}``"
        end
      else
        "`#{string}`"
      end
    end

    def items_to_markdown(items, excerpt_context_length, highlight, &)
      report_items =
        items.map { |category, relevant_morphemes|
          subcategories = relevant_morphemes.map { |m| yield m }
          item_heading =
            "* #{category}: " +
              subcategories.tally.map { |h, count| "#{h} (#{count})" }.join(" | ")
          subitems =
            relevant_morphemes.map { |m|
              source_name = m.line.source_name
              excerpt = excerpt(m, excerpt_context_length, highlight)
              excerpt_md = "#{markup_as_markdown_inline_code(excerpt)}"
              "  - " + [source_name, excerpt_md].compact.join(": ")
            }
          [item_heading, subitems.join("\n")].join("\n")
        }
      report_items.join("\n")
    end

    def items_to_tsv(items, excerpt_context_length, highlight, header, &)
      report_lines =
        items.map { |category, relevant_morphemes|
          relevant_morphemes.map { |m|
            source_name = m.line.source_name
            line_number = m.line.index + 1
            character_number = m.index_in_source_string + 1
            subcategory = yield m
            excerpt = excerpt(m, excerpt_context_length, highlight)
            [category, source_name, line_number, character_number, subcategory, m.surface, excerpt]
              .map(&.to_s.gsub(TSV_ESCAPE_REGEX, TSV_ESCAPE)).join("\t")
          }
        }
      [header, report_lines.flatten.join("\n")].join("\n")
    end

    def report_variants(format, excerpt_context_length, sort_order, highlight, header, exclude_ascii_only_items)
      items = variants(@lines, @yomi_parser, sort_order, exclude_ascii_only_items)
      case format
      in ReportFormat::Text
        items_to_text(items, excerpt_context_length, highlight) { |morpheme|
          surface = morpheme.surface
          if ASCII_WORD_REGEX.match surface
            # Kludge: For ASCII-only words, categorize subitems by surface as a
            # substitute of its dictionary form.
            # TODO: Acquire dictionary forms of foreign words somehow.
            surface
          else
            # In general, categorize subitems by dictionary form.
            morpheme.feature.lexical_form
          end
        }
      in ReportFormat::Markdown
        items_to_markdown(items, excerpt_context_length, highlight) { |morpheme|
          surface = morpheme.surface
          if ASCII_WORD_REGEX.match surface
            surface
          else
            morpheme.feature.lexical_form
          end
        }
      in ReportFormat::TSV
        items_to_tsv(items, excerpt_context_length, highlight, header: header) { |morpheme|
          surface = morpheme.surface
          if ASCII_WORD_REGEX.match surface
            surface
          else
            morpheme.feature.lexical_form
          end
        }
      end
    end

    def report_heteronyms(format, excerpt_context_length, sort_order, highlight, header, exclude_ascii_only_items)
      items = heteronyms(@lines, sort_order, exclude_ascii_only_items)
      case format
      in ReportFormat::Text
        items_to_text(items, excerpt_context_length, highlight) { |morpheme|
          morpheme.feature.yomi # categorize subitems by yomi
        }
      in ReportFormat::Markdown
        items_to_markdown(items, excerpt_context_length, highlight) { |morpheme|
          morpheme.feature.yomi # categorize subitems by yomi
        }
      in ReportFormat::TSV
        items_to_tsv(items, excerpt_context_length, highlight, header: header) { |morpheme|
          morpheme.feature.yomi # categorize subitems by yomi
        }
      end
    end

    def report(type = ReportType::Variants, format = ReportFormat::Text,
               excerpt_context_length = 5, sort_order = SortOrder::Alphabetical,
               highlight = false, header = nil, exclude_ascii_only_items = false)
      # FIXME: the application somehow slows down if we do not use
      # conditionals (case..when) and unify invocations of the same methods
      # (e.g. report_variants(format, excerpt_context_length, sort_order, highlight, header))
      case type
      in ReportType::Variants
        case format
        in ReportFormat::Text
        in ReportFormat::Markdown
        in ReportFormat::TSV
          header ||= TSV_HEADER_VARIANTS
        end
        report_variants(format, excerpt_context_length, sort_order, highlight, header, exclude_ascii_only_items)
      in ReportType::Heteronyms
        case format
        in ReportFormat::Text
        in ReportFormat::Markdown
        in ReportFormat::TSV
          header ||= TSV_HEADER_HETERONYMS
        end
        report_heteronyms(format, excerpt_context_length, sort_order, highlight, header, exclude_ascii_only_items)
      end
    end
  end

  module CLI
    enum Highlight
      Auto
      Always
      Never
    end

    record Config,
      report_type : Document::ReportType,
      report_format : Document::ReportFormat,
      highlight : Highlight,
      excerpt_context_length : Int32 | Tuple(Int32, Int32),
      sort_order : Document::SortOrder,
      exclude_ascii_only_items : Bool,
      pager : String?,
      mecab_dict_dir : String?,
      show_help : Bool,
      show_version : Bool do
      setter :report_type, :report_format, :highlight, :excerpt_context_length,
        :sort_order, :exclude_ascii_only_items, :pager, :mecab_dict_dir, :show_help, :show_version
    end

    DEFAULT_CONFIG =
      Config.new(
        report_type: Document::ReportType::Variants,
        report_format: Document::ReportFormat::Text,
        highlight: Highlight::Auto,
        excerpt_context_length: 5,
        sort_order: Document::SortOrder::Alphabetical,
        exclude_ascii_only_items: false,
        pager: nil,
        mecab_dict_dir: nil,
        show_help: false,
        show_version: false
      )

    def self.puts_or_print(string)
      STDOUT.tty? ? puts(string) : print(string)
    end

    def self.puts_or_write_to_pager(report, pager)
      if STDOUT.tty? && pager && !pager.empty?
        cmd, *args = pager.split
        Process.run(cmd, args,
          input: IO::Memory.new(report), output: STDOUT, error: STDERR)
      else
        puts report
      end
    end

    def self.run
      c = DEFAULT_CONFIG.dup

      op = OptionParser.new do |o|
        o.banner = <<-EOS
          Hyoki helps finding variants in Japanese text

          Usage:
            #{PROGRAM_NAME} [OPTIONS]... [FILE]...

          Options:
          EOS
        o.on("--report-type=variants|heteronyms", <<-EOS.chomp) { |s|
          Choose report type (default: #{c.report_type.to_s.downcase})
          EOS
          c.report_type =
            case s
            when "variants"   then Document::ReportType::Variants
            when "heteronyms" then Document::ReportType::Heteronyms
            else                   raise "Invalid report type: #{s.inspect}"
            end
        }
        o.on("--report-format=text|markdown|tsv", <<-EOS.chomp) { |s|
          Choose report format (default: #{c.report_format.to_s.downcase})
          EOS
          c.report_format =
            case s
            when "text"     then Document::ReportFormat::Text
            when "markdown" then Document::ReportFormat::Markdown
            when "tsv"      then Document::ReportFormat::TSV
            else                 raise "Invalid report format: #{s.inspect}"
            end
        }
        o.on("--highlight=auto|always|never", <<-EOS.chomp) { |s|
          Enable/disable excerpt highlighting (default: #{c.highlight.to_s.downcase})
          EOS
          c.highlight =
            case s
            when "auto"   then Highlight::Auto
            when "always" then Highlight::Always
            when "never"  then Highlight::Never
            else               raise "Invalid value for highlight: #{s.inspect}"
            end
        }
        o.on("--excerpt-context-length=N|N,M", <<-EOS.chomp) { |s|
          Set excerpt context length to N (or preceding N and succeeding M) characters (default: #{c.excerpt_context_length})
          EOS
          c.excerpt_context_length =
            begin
              if s.includes? ","
                Tuple(Int32, Int32).from(s.split(",").map &.to_i)
              else
                s.to_i
              end
            rescue ex : ArgumentError
              raise "Invalid value for excerpt context length: #{ex.message}"
            end
        }
        o.on("--sort-order=alphabetical|appearance", <<-EOS.chomp) { |s|
          Specify how report items should be sorted \
          (default: #{c.sort_order.to_s.downcase})
          EOS
          c.sort_order =
            case s
            when "alphabetical" then Document::SortOrder::Alphabetical
            when "appearance"   then Document::SortOrder::Appearance
            else                     raise "Invalid value for sort_order: #{s.inspect}"
            end
        }
        o.on("--exclude-ascii-only-items=true|false", <<-EOS.chomp) { |s|
          Specify whether to exclude ASCII-only items in the output \
          (default: #{c.exclude_ascii_only_items})
          EOS
          c.exclude_ascii_only_items =
            case s
            when "true"  then true
            when "false" then false
            else              raise "Invalid value for exclude_ascii_only_items: #{s.inspect}"
            end
        }
        o.on("--pager=PAGER", <<-EOS.chomp) { |s|
          Specify pager \
          (default: #{c.pager.to_s.inspect}, falls back to $HYOKI_PAGER or $PAGER)
          EOS
          c.pager = s if s && !s.empty?
        }
        o.on("--mecab-dict-dir=DIR", <<-EOS.chomp) { |s|
          Specify MeCab dictionary directory to use \
          (e.g. /var/lib/mecab/dic/ipadic-utf8)
          EOS
          c.mecab_dict_dir =
            case
            when !(Dir.exists? s)          then raise "Directory not found: #{s.inspect}"
            when !(File::Info.readable? s) then raise "Directory not readable: #{s.inspect}"
            else                                s
            end
        }
        o.on("--help", "Show help message") { c.show_help = true }
        o.on("--version", "Show version") { c.show_version = true }
      end
      op.parse

      if c.show_help
        puts op
        exit 0
      end

      if c.show_version
        puts_or_print Hyoki::VERSION
        exit 0
      end

      highlight =
        case c.highlight
        in Highlight::Auto   then STDOUT.tty?
        in Highlight::Always then true
        in Highlight::Never  then false
        end

      sources =
        if ARGV.empty?
          [ARGF]
        else
          ARGV.map { |a| File.open(a) }
        end

      doc = Hyoki::Document.new(sources, mecab_dict_dir: c.mecab_dict_dir)

      report =
        case type = c.report_type
        in Document::ReportType::Variants,
           Document::ReportType::Heteronyms
          case format = c.report_format
          in Document::ReportFormat::Text,
             Document::ReportFormat::Markdown,
             Document::ReportFormat::TSV
            doc.report(type: type, format: format,
              excerpt_context_length: c.excerpt_context_length,
              sort_order: c.sort_order,
              highlight: highlight,
              exclude_ascii_only_items: c.exclude_ascii_only_items)
          end
        end

      # FIXME: Avoid `Broken pipe (IO::Error)` when piped to a pager.
      # (See https://github.com/crystal-lang/crystal/issues/7810 .)
      if !report.empty?
        pager =
          case
          when (s = c.pager) && !s.empty?             then s
          when (s = ENV["HYOKI_PAGER"]?) && !s.empty? then s
          when (s = ENV["PAGER"]?) && !s.empty?       then s
          end
        puts_or_write_to_pager(report, pager)
      end
    end
  end
end
