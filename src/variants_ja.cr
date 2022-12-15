require "fucoidan"
require "option_parser"

module VariantsJa
  VERSION = "0.1.0"

  class Morpheme
    struct Feature
      FILLER = ["*", "*", "*", "*", "*", "*", "*", "*", "*"]

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
        # kludge: padding values, since the number of values is not predictable
        values = feature_csv.split(",").concat FILLER
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
      n = node
      @surface = n.surface
      @feature = Feature.new(n.feature)
      @length = n.length
      @rlength = n.rlength
      @node_id = n.id
      @rc_attr = n.rcAttr
      @lc_attr = n.lcAttr
      @posid = n.posid
      @char_type = n.char_type
      @stat = n.stat
      @isbest = n.isbest
      @alpha = n.alpha
      @beta = n.beta
      @prob = n.prob
      @wcost = n.wcost
      @cost = n.cost
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
      string.scan(Regex.new(Regex.escape(substring))).map { |md| md.begin }
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

  class Document
    LINE_REGEX =
      /^(.*?)((?:\r\n|\r|\n)*)$/
    TSV_ESCAPE =
      {"\n" => "\\n", "\t" => "\\t", "\r" => "\\r", "\\" => "\\\\"}
    TSV_ESCAPE_REGEX =
      Regex.new(TSV_ESCAPE.keys.map { |k| "(?:#{Regex.escape(k)})" }.join("|"))

    struct Line
      @source : String
      @body : String
      @eol : String
      @index : Int32
      @morphemes : Array(Morpheme) | Nil
      @parser : Fucoidan::Fucoidan

      def initialize(source, index, parser)
        body, eol = source.scan(LINE_REGEX).first
        @source = source
        @body = body
        @eol = eol
        @index = index
        @morphemes = nil
        @parser = parser
      end

      getter :body, :eol, :index

      def morphemes
        @morphemes ||= VariantsJa.string_to_morphemes(body, self, @parser)
      end
    end

    @lines : Array(Line)
    @parser : Fucoidan::Fucoidan
    @yomi_parser : Fucoidan::Fucoidan

    def initialize(string, mecab_dict_dir = nil)
      mecab_opts = [] of String
      mecab_opts << "--dicdir=#{mecab_dict_dir}" if mecab_dict_dir
      @parser = Fucoidan::Fucoidan.new(mecab_opts.join(" "))
      @yomi_parser = Fucoidan::Fucoidan.new((mecab_opts + ["-Oyomi"]).join(" "))
      @lines = string.lines.map_with_index { |str, i| Line.new(str, i, @parser) }
    end

    getter :lines

    def variants(lines, yomi_parser, sort)
      morphemes_by_yomi =
        lines.map { |l| l.morphemes }.flatten.group_by { |m|
          VariantsJa.yomi(m.feature.lexical_form, yomi_parser)
        }
      variants =
        morphemes_by_yomi.select { |_lexical_form_yomi, morphemes_of_same_yomi|
          morphemes_of_same_yomi.map { |m| m.feature.lexical_form }.uniq.size >= 2
        }
      case sort
      when :alphabetical
        variants.to_a.sort_by { |lexical_form_yomi, _morphemes_of_same_yomi|
          lexical_form_yomi # sort sections by yomi of lexical form
        }
      when :appearance
        variants.to_a
      else
        raise "Invalid sort order: #{sort}"
      end
    end

    def heteronyms(lines, sort)
      morphemes_by_surface =
        lines.map { |l| l.morphemes }.flatten.group_by { |m|
          m.surface
        }
      heteronyms =
        morphemes_by_surface.select { |_surface, morphemes_of_same_surface|
          morphemes_of_same_surface.map { |m| m.feature.yomi }.uniq.size >= 2
        }
      case sort
      when :alphabetical
        heteronyms.to_a.sort_by { |surface, _morphemes_of_same_surface|
          surface
        }
      when :appearance
        heteronyms.to_a
      else
        raise "Invalid sort order: #{sort}"
      end
    end

    def excerpt(morpheme, context_before, context_after, color = nil)
      line = morpheme.line
      string_index = morpheme.string_index
      prefix =
        if (leftmost = string_index - context_before) && leftmost.negative?
          line.body[0, string_index]
        else
          line.body[leftmost, context_before]
        end
      body = morpheme.surface
      suffix = line.body[(string_index + body.size), context_after]

      if color
        # 1: Bold, 4: Underline, 7: Invert, 0: Reset
        [prefix, "\e[1;4;7m", body, "\e[0m", suffix].join
      else
        [prefix, body, suffix].join
      end
    end

    def report_variants_text(context_before = 5, context_after = 5, sort = :alphabetical, color = false)
      variants = variants(@lines, @yomi_parser, sort)
      report_items =
        variants.map { |lexical_form_yomi, morphemes_of_same_yomi|
          lexical_forms = morphemes_of_same_yomi.map { |m| m.feature.lexical_form }
          item_heading =
            "#{lexical_form_yomi}: " + lexical_forms.tally.map { |item_name, count|
              "#{item_name} (#{count})"
            }.join(" | ")
          item_lines =
            morphemes_of_same_yomi.map { |m|
              line = m.line
              string_index = m.string_index
              line_number = line.index + 1
              character_number = string_index + 1
              subitem = m.feature.lexical_form
              excerpt = excerpt(m, context_before, context_after, color)
              "\tL#{line_number}, C#{character_number}\t#{subitem}\t#{excerpt}"
            }
          item_body = item_lines.join("\n")
          [item_heading, item_body].join("\n")
        }
      report_items.join("\n")
    end

    def report_variants_tsv(context_before = 5, context_after = 5, sort = :alphabetical)
      variants = variants(@lines, @yomi_parser, sort)
      report_lines =
        variants.map { |lexical_form_yomi, morphemes_of_same_yomi|
          morphemes_of_same_yomi.map { |m|
            line = m.line
            string_index = m.string_index
            category = lexical_form_yomi
            line_number = line.index + 1
            character_number = string_index + 1
            subcategory = m.feature.lexical_form
            excerpt = excerpt(m, context_before, context_after)
            [
              category,
              line_number,
              character_number,
              subcategory,
              m.surface,
              excerpt,
            ].map { |v| v.to_s.gsub(TSV_ESCAPE_REGEX, TSV_ESCAPE) }.join("\t")
          }
        }
      report_header =
        [
          "lexical form yomi",
          "line",
          "character",
          "lexical form",
          "surface",
          "excerpt",
        ].join("\t")
      [report_header, report_lines.flatten.join("\n")].join("\n")
    end

    def report_heteronyms_text(context_before = 5, context_after = 5, sort = :alphabetical, color = false)
      heteronyms = heteronyms(@lines, sort)
      report_items =
        heteronyms.map { |surface, morphemes_of_same_surface|
          yomis = morphemes_of_same_surface.map { |m| m.feature.yomi }
          item_heading =
            "#{surface}: " + yomis.tally.map { |item_name, count|
              "#{item_name} (#{count})"
            }.join(" | ")
          item_lines =
            morphemes_of_same_surface.map { |m|
              line = m.line
              string_index = m.string_index
              line_number = line.index + 1
              character_number = string_index + 1
              subitem = m.feature.yomi
              excerpt = excerpt(m, context_before, context_after, color)
              "\tL#{line_number}, C#{character_number}\t#{subitem}\t#{excerpt}"
            }
          item_body = item_lines.join("\n")
          [item_heading, item_body].join("\n")
        }
      report_items.join("\n")
    end

    def report_heteronyms_tsv(context_before = 5, context_after = 5, sort = :alphabetical)
      heteronyms = heteronyms(@lines, sort)
      report_lines =
        heteronyms.map { |surface, morphemes_of_same_surface|
          morphemes_of_same_surface.map { |m|
            line = m.line
            string_index = m.string_index
            category = surface
            line_number = line.index + 1
            character_number = string_index + 1
            subcategory = m.feature.yomi
            excerpt = excerpt(m, context_before, context_after)
            [
              category,
              line_number,
              character_number,
              subcategory,
              m.surface,
              excerpt,
            ].map { |v| v.to_s.gsub(TSV_ESCAPE_REGEX, TSV_ESCAPE) }.join("\t")
          }
        }
      report_header =
        [
          "surface",
          "line",
          "character",
          "yomi",
          "surface",
          "excerpt",
        ].join("\t")
      [report_header, report_lines.flatten.join("\n")].join("\n")
    end
  end

  module CLI
    record Config,
      report_type : Symbol,
      output_format : Symbol,
      color : Symbol,
      context : Int32,
      sort : Symbol,
      mecab_dict_dir : String | Nil,
      show_help : Bool,
      show_version : Bool do
      setter :report_type, :output_format, :color, :context, :sort,
        :mecab_dict_dir, :show_help, :show_version
    end

    DEFAULT_CONFIG =
      Config.new(
        report_type: :variants,
        output_format: :text,
        color: :auto,
        context: 5,
        sort: :alphabetical,
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
          Help finding variants (hyoki-yure) in Japanese text

          Usage:
            #{PROGRAM_NAME} [OPTIONS] input.txt

          Options:
          EOS
        o.on("--report-type=variants|heteronyms", <<-EOS.chomp) { |s|
          Choose report type (default: #{c.report_type})
          EOS
          c.report_type =
            case s
            when "variants"   then :variants
            when "heteronyms" then :heteronyms
            else                   raise "Invalid value for report type: #{s}"
            end
        }
        o.on("--output-format=text|tsv", <<-EOS.chomp) { |s|
          Choose output format (default: #{c.output_format})
          EOS
          c.output_format =
            case s
            when "text" then :text
            when "tsv"  then :tsv
            else             raise "Invalid value for output format: #{s}"
            end
        }
        o.on("--color=auto|always|never", <<-EOS.chomp) { |s|
          Enable/disable excerpt highlighting using ANSI escape sequence \
          for text output (default: #{c.color})
          EOS
          c.color =
            case s
            when "auto"   then :auto
            when "always" then :always
            when "never"  then :never
            else               raise "Invalid value for color: #{s}"
            end
        }
        o.on("--context=N", <<-EOS.chomp) { |s|
          Set excerpt context to N characters (default: #{c.context})
          EOS
          c.context =
            begin
              s.to_i
            rescue ex : ArgumentError
              raise "Invalid value for context: #{ex.message}"
            end
        }
        o.on("--sort=alphabetical|appearance", <<-EOS.chomp) { |s|
          Specify how report items/records should be sorted \
          (default: #{c.sort})
          EOS
          c.sort =
            case s
            when "alphabetical" then :alphabetical
            when "appearance"   then :appearance
            else                     raise "Invalid value for sort: #{s}"
            end
        }
        o.on("--mecab-dict-dir=DIR", <<-EOS.chomp) { |s|
          Specify MeCab dictionary directory to use \
          (e.g. /var/lib/mecab/dic/naist-jdic)
          EOS
          c.mecab_dict_dir =
            case
            when !(Dir.exists? s)    then raise "Directory not found: #{s}"
            when !(File.readable? s) then raise "Directory not readable: #{s}"
            else                          s
            end
        }
        o.on("--help", "Show help message") { c.show_help = true }
        o.on("--version", "Show version") { c.show_version = true }
      end
      op.parse

      if c.show_help
        puts_or_print op
        exit 0
      end

      if c.show_version
        puts_or_print VariantsJa::VERSION
        exit 0
      end

      color =
        case c.color
        when :auto   then STDOUT.tty?
        when :always then true
        when :never  then false
        else              raise "Invalid tty option value: #{c.color}"
        end

      doc = VariantsJa::Document.new(ARGF.gets_to_end, mecab_dict_dir: c.mecab_dict_dir)

      report =
        case c.report_type
        when :variants
          case c.output_format
          when :text then doc.report_variants_text(context_before: c.context, context_after: c.context, sort: c.sort, color: color)
          when :tsv  then doc.report_variants_tsv(context_before: c.context, context_after: c.context, sort: c.sort)
          else            raise "Invalid output format: #{c.output_format.inspect}"
          end
        when :heteronyms
          case c.output_format
          when :text then doc.report_heteronyms_text(context_before: c.context, context_after: c.context, sort: c.sort, color: color)
          when :tsv  then doc.report_heteronyms_tsv(context_before: c.context, context_after: c.context, sort: c.sort)
          else            raise "Invalid output format: #{c.output_format.inspect}"
          end
        else
          raise "Invalid report type: #{c.report_type.inspect}"
        end

      puts_or_print report unless report.empty?
    end
  end

  def self.called_as_an_application?
    File.basename(__FILE__, ".cr") == File.basename(PROGRAM_NAME)
  end
end

VariantsJa::CLI.run if VariantsJa.called_as_an_application?
