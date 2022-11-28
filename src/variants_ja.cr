require "fucoidan"
require "option_parser"

module VariantsJa
  VERSION = "0.1.0"

  class Morpheme
    class Feature
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
        # kludge: padding values because number of values is not predictable
        values = feature_csv.split(",") + Array(String).new(99, "*")
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
    @line : VariantsJa::Document::Line
    @index : Int32
    @string_index : Int32 | Nil

    def initialize(node, line, index)
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
      @line = line
      @index = index
      @string_index = nil
    end

    getter :surface, :feature, :length, :rlength, :node_id, :rc_attr,
      :lc_attr, :posid, :char_type, :stat, :isbest, :alpha, :beta, :prob,
      :wcost, :cost, :line, :index

    def string_indexes(string, substring, preceding_length = 0)
      head, sep, tail = string.partition(substring)
      case
      when sep.empty? # found none
        [] of Int32
      when tail.empty? # found the last one
        [head.size + preceding_length]
      else # found one
        if tail.includes? substring
          [head.size + preceding_length] +
            string_indexes(tail, substring,
              preceding_length: preceding_length + head.size + sep.size)
        else
          [head.size + preceding_length]
        end
      end
    end

    def string_index
      str_indexes = string_indexes(line.body, surface)
      str_length = line.body.size
      str_index_proportions = str_indexes.map { |str_idx| str_idx.to_f / str_length }
      str_indexes_to_proportions = str_indexes.zip(str_index_proportions).to_h

      morpheme_index_proportion = index.to_f / line.morphemes.last.index

      guessed_string_index_candidates =
        str_indexes_to_proportions.to_a.sort_by { |_str_idx, str_idx_prop|
          # add 0.01 to avoid dealing with zero
          ((str_idx_prop + 0.01) / (morpheme_index_proportion + 0.01) - 1).abs
        }
      best_guess = guessed_string_index_candidates.first.first

      @string_index ||= best_guess
    end
  end

  class Document
    RE_LINE = /^(.*?)((?:\r\n|\r|\n)*)$/

    class Line
      @source : String
      @body : String
      @eol : String
      @index : Int32
      @morphemes : Array(Morpheme)

      def initialize(source, body, eol, index, morphemes = [] of Morpheme)
        @source = source
        @body = body
        @eol = eol
        @index = index
        @morphemes = morphemes
      end

      getter :body, :eol, :index
      property :morphemes
    end

    @lines : Array(Line)

    def initialize(string)
      @lines = string.lines.map_with_index { |source, i|
        body, eol = source.scan(RE_LINE).first
        line = Line.new(source, body, eol, i)
        line.morphemes = string_to_morphemes(body, line)
        line
      }
    end

    getter :lines

    def string_to_morphemes(string, line)
      # remove BOS/EOS at nodes[0] and nodes[-1]
      nodes = Fucoidan::Fucoidan.new.enum_parse(string).to_a.reject! { |n|
        n.feature.starts_with? "BOS/EOS"
      }
      nodes.map_with_index { |n, i|
        Morpheme.new(n, line, i)
      }
    end

    def yomi(string)
      body, eol = string.scan(RE_LINE).first
      line = Line.new(string, body, eol, 0)
      string_to_morphemes(string, line).first.feature.yomi
    end

    EXCERPT_FORMATTER = {
      :tty => ->(context_before : String, body : String, context_after : String) {
        # 1:Bold, 4:Underline, 7:Invert, 0:Reset
        [context_before, "\e[1;4;7;22m", body, "\e[0m", context_after].join
      },
      :asis => ->(context_before : String, body : String, context_after : String) {
        [context_before, body, context_after].join
      },
    }

    def report_variants_text(context_before = 5, context_after = 5, tty = false)
      excerpt_formatter =
        if tty
          EXCERPT_FORMATTER[:tty]
        else
          EXCERPT_FORMATTER[:asis]
        end

      morphemes_by_yomi =
        @lines.map { |l| l.morphemes }.flatten.group_by { |m|
          yomi(m.feature.lexical_form)
        }

      variants =
        morphemes_by_yomi.select { |_lexical_form_yomi, morphemes_of_same_yomi|
          morphemes_of_same_yomi.map { |m| m.feature.lexical_form }.sort.uniq.size >= 2
        }.to_h

      report_sections =
        variants.map { |lexical_form_yomi, morphemes_of_same_yomi|
          lexical_forms = morphemes_of_same_yomi.map { |m| m.feature.lexical_form }
          section_heading =
            "#{lexical_form_yomi}: " +
              lexical_forms.tally.map { |form, count|
                "#{form} (#{count})"
              }.join(" | ")
          section_lines =
            morphemes_of_same_yomi.map { |m|
              line_number = m.line.index + 1
              character_number = m.string_index + 1
              excerpt_context_before =
                if (leftmost = m.string_index - context_before) && leftmost.negative?
                  m.line.body[0, m.string_index]
                else
                  m.line.body[leftmost, context_before]
                end
              excerpt_body = m.surface
              excerpt_context_after =
                m.line.body[(m.string_index + m.surface.size), context_after]
              excerpt =
                excerpt_formatter.call(excerpt_context_before,
                  excerpt_body,
                  excerpt_context_after)
              "\tL#{line_number}, C#{character_number}\t#{excerpt}"
            }
          section_body = section_lines.join("\n")
          section = [section_heading, section_body].join("\n")
        }

      report = report_sections.join("\n")
    end

    def report_variants_tsv(context_before = 5, context_after = 5)
      characters_to_escape =
        {"\n" => "\\n", "\t" => "\\t", "\r" => "\\r", "\\" => "\\\\"}

      excerpt_formatter = EXCERPT_FORMATTER[:asis]

      morphemes_by_yomi =
        @lines.map { |m| m.morphemes }.flatten.group_by { |m|
          yomi(m.feature.lexical_form)
        }

      variants =
        morphemes_by_yomi.select { |_lexical_form_yomi, morphemes_of_same_yomi|
          morphemes_of_same_yomi.map { |m| m.feature.lexical_form }.sort.uniq.size >= 2
        }.to_h

      report_lines =
        variants.map { |lexical_form_yomi, morphemes_of_same_yomi|
          morphemes_of_same_yomi.map { |m|
            line_number = m.line.index + 1
            character_number = m.string_index + 1
            excerpt_context_before =
              if (leftmost = m.string_index - context_before) && leftmost.negative?
                m.line.body[0, m.string_index]
              else
                m.line.body[leftmost, context_before]
              end
            excerpt_body = m.surface
            excerpt_context_after =
              m.line.body[(m.string_index + m.surface.size), context_after]
            excerpt =
              excerpt_formatter.call(excerpt_context_before,
                excerpt_body,
                excerpt_context_after)
            a_line =
              [
                lexical_form_yomi,
                line_number,
                character_number,
                m.feature.lexical_form,
                m.surface,
                excerpt,
              ].map { |v|
                # escape for TSV
                v.to_s.gsub(characters_to_escape.keys.join("|"), characters_to_escape)
              }.join("\t")
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

      report =
        [report_header, report_lines.flatten.join("\n")].join("\n")
    end
  end

  module CLI
    record Config,
      output_format : Symbol,
      tty : Symbol,
      context : Int32,
      mecab_dict_dir : String | Nil,
      show_help : Bool,
      show_version : Bool do
      setter :output_format, :tty, :context, :mecab_dict_dir, :show_help, :show_version
    end

    DEFAULT_CONFIG =
      Config.new(
        output_format: :text,
        tty: :auto,
        context: 5,
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
        o.on("--output-format=text|tsv", <<-EOS.chomp) { |s|
          Specify output format (default: #{c.output_format})
          EOS
          c.output_format =
            case s
            when "text" then :text
            when "tsv"  then :tsv
            else             raise "Invalid output format"
            end
        }
        o.on("--tty=always|never|auto", <<-EOS.chomp) { |s|
          Enable/disable highlighting using ANSI escape sequence for text output \
          (default: #{c.tty})
          EOS
          c.tty =
            case s
            when "always" then :always
            when "never"  then :never
            when "auto"   then :auto
            else
              raise "Invalid option value: tty must be always, never, or auto"
            end
        }
        o.on("--context=N", <<-EOS.chomp) { |s|
          Set excerpt context to N characters (default: #{c.context})
          EOS
          c.context =
            begin
              s.to_i
            rescue ex : ArgumentError
              raise "Invalid option value: context must be integer: #{ex.message}"
            end
        }
        o.on("--mecab-dict-dir=DIR", <<-EOS.chomp) { |s|
          Specify MeCab dictionary directory to use \
          (e.g. /var/lib/mecab/dic/naist-jdic)
          EOS
          c.mecab_dict_dir = s
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

      tty =
        case c.tty
        when :auto   then STDOUT.tty?
        when :always then true
        when :never  then false
        else              raise "Invalid tty option value: #{c.tty}"
        end

      doc = VariantsJa::Document.new(ARGF.gets_to_end)

      report =
        case c.output_format
        when :text
          doc.report_variants_text(context_before: c.context,
            context_after: c.context,
            tty: tty)
        when :tsv
          doc.report_variants_tsv(context_before: c.context,
            context_after: c.context)
        else
          raise "Invalid output format: #{c.output_format.inspect}"
        end
      puts_or_print report unless report.empty?
    end
  end

  def self.called_as_an_application?
    File.basename(__FILE__, ".cr") == File.basename(PROGRAM_NAME)
  end
end

VariantsJa::CLI.run if VariantsJa.called_as_an_application?
