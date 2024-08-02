require "fucoidan"
require "option_parser"

module Hyoki
  VERSION = "0.2.0"

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
    @string_index : Int32

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
      @string_index = -100 # FIXME: kludge to pass typechecking
    end

    getter :surface, :feature, :length, :rlength, :node_id, :rc_attr,
      :lc_attr, :posid, :char_type, :stat, :isbest, :alpha, :beta, :prob,
      :wcost, :cost, :index, :source_string, :line

    def string_indexes(string, substring)
      string.scan(Regex.new(Regex.escape(substring))).map(&.begin)
    end

    def string_index
      if @string_index >= 0 # FIXME: kludge to pass typechecking
        @string_index
      else
        str_idxs = string_indexes(@source_string, @surface)
        str_len = @source_string.size
        # add 0.01 to avoid divide-by-zero error
        str_idx_proportions = str_idxs.map { |str_idx| (str_idx.to_f / str_len) + 0.01 }
        morpheme_idx_proportion = (@index.to_f / @max_index) + 0.01
        str_idx_candidates =
          str_idxs.zip(str_idx_proportions).sort_by { |_str_idx, str_idx_prop|
            (str_idx_prop / morpheme_idx_proportion - 1.0).abs
          }
        @string_index = str_idx_candidates.first.first # best guess
      end
    end
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

    struct Line
      @source_string : String
      @body : String
      @eol : String | Nil
      @index : Int32
      @morphemes : Array(Morpheme) | Nil
      @parser : Fucoidan::Fucoidan
      @source_name : String | Nil

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
    def variants(lines, yomi_parser, sort, include_ascii) : ReportItems
      morphemes_by_lexical_form_yomi =
        lines.flat_map(&.morphemes).group_by { |m|
          # Group morphemes by yomi of lexical form.
          #   * When surface and lexical form are the same, yomi of surface
          #     can be used as yomi of lexical form.
          #   * Otherwise (when surface differs from lexical form because of
          #     conjugation and such), we try to guess yomi of lexical form.
          #   * Kludge: For ASCII words, we use downcased surface as a
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
              # Kludge: For ASCII words, use surface as a substitute of
              # lexical form.
              surface
            else
              m.feature.lexical_form
            end
          }.uniq!.size >= 2
        }

      # exclude ASCII-only items if specified such.
      if include_ascii == false
        lexical_form_yomi_to_variants.reject! { |key, _morphemes|
          ASCII_WORD_REGEX.match(key)
        }
      end

      case sort
      when :alphabetical
        lexical_form_yomi_to_variants.to_a.sort_by { |lfyomi, _morphemes_of_same_lfyomi|
          lfyomi
        }
      when :appearance
        lexical_form_yomi_to_variants.to_a
      else
        raise "Invalid sort order: #{sort.inspect}"
      end
    end

    # Returns an associative list of surface expression to heteronyms: words
    # with same spelling and different pronunciation.
    def heteronyms(lines, sort, include_ascii) : ReportItems
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
      if include_ascii == false
        surface_to_heteronyms.reject! { |key, _morphemes|
          ASCII_WORD_REGEX.match(key)
        }
      end

      case sort
      when :alphabetical
        surface_to_heteronyms.to_a.sort_by { |surface, _morphemes_of_same_surface|
          surface
        }
      when :appearance
        surface_to_heteronyms.to_a
      else
        raise "Invalid sort order: #{sort.inspect}"
      end
    end

    def excerpt(morpheme, context, color = nil)
      surface = morpheme.surface
      string_index = morpheme.string_index
      line_body = morpheme.line.body
      context_length_before, context_length_after =
        case context
        in Int32               then {context, context}
        in Tuple(Int32, Int32) then context
        end
      leftmost = string_index - context_length_before

      if color
        prefix =
          if leftmost.negative?
            line_body[0, string_index]
          else
            line_body[leftmost, context_length_before]
          end
        body = surface
        suffix = line_body[(string_index + body.size), context_length_after]
        # 1: Bold, 4: Underline, 7: Invert, 0: Reset
        "#{prefix}\e[1;4;7m#{body}\e[0m#{suffix}"
      else
        if leftmost.negative?
          line_body[0, (string_index + surface.size + context_length_after)]
        else
          line_body[leftmost, (context_length_before + surface.size + context_length_after)]
        end
      end
    end

    def items_to_text(items, context, color, &)
      report_items =
        items.map { |category, relevant_morphemes|
          subcategories = relevant_morphemes.map { |m| yield m }
          item_heading =
            "## #{category}: " +
              subcategories.tally.map { |h, count| "#{h} (#{count})" }.join(" | ")
          subitems =
            relevant_morphemes.map { |m|
              source_name = m.line.source_name
              line_number = m.line.index + 1
              character_number = m.string_index + 1
              subcategory = yield m
              excerpt = excerpt(m, context, color)
              "    " +
                [source_name,
                 "L#{line_number}, C#{character_number}",
                 subcategory,
                 excerpt].compact.join("\t")
            }
          [item_heading, subitems.join("\n")].join("\n")
        }
      report_items.join("\n")
    end

    def items_to_tsv(items, context, color, header, &)
      report_lines =
        items.map { |category, relevant_morphemes|
          relevant_morphemes.map { |m|
            source_name = m.line.source_name
            line_number = m.line.index + 1
            character_number = m.string_index + 1
            subcategory = yield m
            excerpt = excerpt(m, context, color)
            [category, source_name, line_number, character_number, subcategory, m.surface, excerpt]
              .map(&.to_s.gsub(TSV_ESCAPE_REGEX, TSV_ESCAPE)).join("\t")
          }
        }
      [header, report_lines.flatten.join("\n")].join("\n")
    end

    def report_variants(format, context, sort, color, header, include_ascii)
      items = variants(@lines, @yomi_parser, sort, include_ascii)
      case format
      when :text
        items_to_text(items, context, color) { |morpheme|
          surface = morpheme.surface
          if ASCII_WORD_REGEX.match surface
            # Kludge: For ASCII words, categorize subitems by surface as a
            # substitute of its dictionary form.
            # TODO: Acquire dictionary forms of foreign words somehow.
            surface
          else
            # In general, categorize subitems by dictionary form.
            morpheme.feature.lexical_form
          end
        }
      when :tsv
        items_to_tsv(items, context, color, header: header) { |morpheme|
          surface = morpheme.surface
          if ASCII_WORD_REGEX.match surface
            surface
          else
            morpheme.feature.lexical_form
          end
        }
      else
        raise "Invalid report format: #{format.inspect}"
      end
    end

    def report_heteronyms(format, context, sort, color, header, include_ascii)
      items = heteronyms(@lines, sort, include_ascii)
      case format
      when :text
        items_to_text(items, context, color) { |morpheme|
          morpheme.feature.yomi # categorize subitems by yomi
        }
      when :tsv
        items_to_tsv(items, context, color, header: header) { |morpheme|
          morpheme.feature.yomi # categorize subitems by yomi
        }
      else
        raise "Invalid report format: #{format.inspect}"
      end
    end

    def report(type = :variants, format = :text, context = 5,
               sort = :alphabetical, color = false, header = nil,
               include_ascii = true)
      # FIXME: the application somehow slows down if we do not use
      # conditionals (case..when) and unify invocations of the same methods
      # (e.g. report_variants(format, context, sort, color, header))
      case type
      when :variants
        case format
        when :text
          report_variants(format, context, sort, color, header, include_ascii)
        when :tsv
          header ||= TSV_HEADER_VARIANTS
          report_variants(format, context, sort, color, header, include_ascii)
        else
          raise "Invalid report format: #{format.inspect}"
        end
      when :heteronyms
        case format
        when :text
          report_heteronyms(format, context, sort, color, header, include_ascii)
        when :tsv
          header ||= TSV_HEADER_HETERONYMS
          report_heteronyms(format, context, sort, color, header, include_ascii)
        else
          raise "Invalid report format: #{format.inspect}"
        end
      else
        raise "Invalid report type: #{type.inspect}"
      end
    end
  end

  module CLI
    record Config,
      report_type : Symbol,
      report_format : Symbol,
      color : Symbol,
      context : Int32 | Tuple(Int32, Int32),
      sort : Symbol,
      include_ascii : Bool,
      mecab_dict_dir : String | Nil,
      show_help : Bool,
      show_version : Bool do
      setter :report_type, :report_format, :color, :context, :sort,
        :include_ascii, :mecab_dict_dir, :show_help, :show_version
    end

    DEFAULT_CONFIG =
      Config.new(
        report_type: :variants,
        report_format: :text,
        color: :auto,
        context: 5,
        sort: :alphabetical,
        include_ascii: true,
        mecab_dict_dir: nil,
        show_help: false,
        show_version: false
      )

    def self.puts_or_print(string)
      STDOUT.tty? ? puts(string) : print(string)
    end

    def self.run
      c = DEFAULT_CONFIG.dup

      op = OptionParser.new do |o|
        o.banner = <<-EOS
          Help finding variants in Japanese text

          Usage:
            #{PROGRAM_NAME} [OPTION]... [FILE]...

          Options:
          EOS
        o.on("--report-type=variants|heteronyms", <<-EOS.chomp) { |s|
          Choose report type (default: #{c.report_type})
          EOS
          c.report_type =
            case s
            when "variants"   then :variants
            when "heteronyms" then :heteronyms
            else                   raise "Invalid report type: #{s.inspect}"
            end
        }
        o.on("--report-format=text|tsv", <<-EOS.chomp) { |s|
          Choose report format (default: #{c.report_format})
          EOS
          c.report_format =
            case s
            when "text" then :text
            when "tsv"  then :tsv
            else             raise "Invalid report format: #{s.inspect}"
            end
        }
        o.on("--color=auto|always|never", <<-EOS.chomp) { |s|
          Enable/disable excerpt highlighting (default: #{c.color})
          EOS
          c.color =
            case s
            when "auto"   then :auto
            when "always" then :always
            when "never"  then :never
            else               raise "Invalid value for color: #{s.inspect}"
            end
        }
        o.on("--context=N|N,M", <<-EOS.chomp) { |s|
          Set excerpt context to N (or preceding N and succeeding M) characters (default: #{c.context})
          EOS
          c.context =
            begin
              if s.includes? ","
                Tuple(Int32, Int32).from(s.split(",").map &.to_i)
              else
                s.to_i
              end
            rescue ex : ArgumentError
              raise "Invalid value for context: #{ex.message}"
            end
        }
        o.on("--sort=alphabetical|appearance", <<-EOS.chomp) { |s|
          Specify how report items should be sorted \
          (default: #{c.sort})
          EOS
          c.sort =
            case s
            when "alphabetical" then :alphabetical
            when "appearance"   then :appearance
            else                     raise "Invalid value for sort: #{s.inspect}"
            end
        }
        o.on("--include-ascii=true|false", <<-EOS.chomp) { |s|
          Specify whether to include ASCII-only items in the output \
          (default: #{c.include_ascii})
          EOS
          c.include_ascii =
            case s
            when "true"  then true
            when "false" then false
            else              raise "Invalid value for include_ascii: #{s.inspect}"
            end
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

      color =
        case c.color
        when :auto   then STDOUT.tty?
        when :always then true
        when :never  then false
        else              raise "Invalid value for color: #{c.color.inspect}"
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
        when :variants
          case format = c.report_format
          when :text
            doc.report(type: type, format: format, context: c.context, sort: c.sort, color: color, include_ascii: c.include_ascii)
          when :tsv
            doc.report(type: type, format: format, context: c.context, sort: c.sort, color: color, include_ascii: c.include_ascii)
          else
            raise "Invalid report format: #{format.inspect}"
          end
        when :heteronyms
          case format = c.report_format
          when :text
            doc.report(type: type, format: format, context: c.context, sort: c.sort, color: color, include_ascii: c.include_ascii)
          when :tsv
            doc.report(type: type, format: format, context: c.context, sort: c.sort, color: color, include_ascii: c.include_ascii)
          else
            raise "Invalid report format: #{format.inspect}"
          end
        else
          raise "Invalid report type: #{type.inspect}"
        end

      # FIXME: Avoid `Broken pipe (IO::Error)` when piped to a pager.
      # (See https://github.com/crystal-lang/crystal/issues/7810 .)
      puts report unless report.empty?
    end
  end
end
