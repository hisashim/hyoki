require "colorize"
require "./document/line"

module Hyoki
  struct Document
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

    struct Highlighter
      def apply(str : String)
        str.colorize.toggle(true).bold.underline.reverse
      end
    end

    @lines : Array(Line)
    @parser : Fucoidan::Fucoidan
    @yomi_parser : Fucoidan::Fucoidan

    def self.yomi(string, yomi_parser)
      yomi_parser.parse(string).chomp
    end

    def initialize(source_ios : Array(IO), mecab_dict_dir = nil)
      mecab_opts = [] of String
      mecab_opts << "--dicdir=#{mecab_dict_dir}" if mecab_dict_dir
      @parser = Fucoidan::Fucoidan.new(mecab_opts.join(" "))
      @yomi_parser = Fucoidan::Fucoidan.new((mecab_opts + ["-Oyomi"]).join(" "))
      @lines =
        source_ios.reduce([] of Line) do |lines, source_io|
          current_source_lines =
            source_io.gets_to_end.scan(Line::LINE_REGEX).map do |md|
              md[0]
            end.map_with_index do |str, i|
              Line.new(str, i, @parser, source_io: source_io)
            end
          lines.concat(current_source_lines)
        end
    end

    def initialize(string : String, mecab_dict_dir = nil)
      initialize([IO::Memory.new(string)], mecab_dict_dir)
    end

    getter :lines

    # Returns an associative list of yomi (of dictionary form) to
    # variants: words with same pronunciation and different spelling.
    def variants(lines, yomi_parser, sort_order, exclude_ascii_only_items) : ReportItems
      morphemes_by_lexical_form_yomi =
        lines.flat_map(&.morphemes).group_by do |m|
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
            Document.yomi(lexical_form, yomi_parser)
          end
        end
      lexical_form_yomi_to_variants =
        morphemes_by_lexical_form_yomi.select do |_lfyomi, morphemes_of_same_lfyomi|
          morphemes_of_same_lfyomi.map do |m|
            surface = m.surface
            if ASCII_WORD_REGEX.match surface
              # Kludge: For ASCII-only words, use surface as a substitute of
              # lexical form.
              surface
            else
              m.feature.lexical_form
            end
          end.uniq!.size >= 2
        end

      # exclude ASCII-only items if specified such.
      if exclude_ascii_only_items == true
        lexical_form_yomi_to_variants.reject! do |key, _morphemes|
          ASCII_WORD_REGEX.match(key)
        end
      end

      case sort_order
      in SortOrder::Alphabetical
        lexical_form_yomi_to_variants.to_a.sort_by do |lfyomi, _morphemes_of_same_lfyomi|
          lfyomi
        end
      in SortOrder::Appearance
        lexical_form_yomi_to_variants.to_a
      end
    end

    # Returns an associative list of surface expression to heteronyms: words
    # with same spelling and different pronunciation.
    def heteronyms(lines, sort_order, exclude_ascii_only_items) : ReportItems
      morphemes_by_surface =
        lines.flat_map(&.morphemes).group_by do |m|
          # group morphemes by surface expression
          m.surface
        end
      surface_to_heteronyms =
        morphemes_by_surface.select do |_surface, morphemes_of_same_surface|
          morphemes_of_same_surface.map(&.feature.yomi).uniq!.size >= 2
        end

      # exclude ASCII-only items if specified such.
      if exclude_ascii_only_items == true
        surface_to_heteronyms.reject! do |key, _morphemes|
          ASCII_WORD_REGEX.match(key)
        end
      end

      case sort_order
      in SortOrder::Alphabetical
        surface_to_heteronyms.to_a.sort_by do |surface, _morphemes_of_same_surface|
          surface
        end
      in SortOrder::Appearance
        surface_to_heteronyms.to_a
      end
    end

    def excerpt(morpheme, context_length, highlighter : Highlighter? = nil)
      surface = morpheme.surface
      index = morpheme.index_in_source_string
      line_body = morpheme.line.body
      context_length_before, context_length_after =
        case context_length
        in Int32               then {context_length, context_length}
        in Tuple(Int32, Int32) then context_length
        end
      leftmost = index - context_length_before

      if highlighter
        prefix =
          if leftmost.negative?
            line_body[0, index]
          else
            line_body[leftmost, context_length_before]
          end
        body = surface
        suffix = line_body[(index + body.size), context_length_after]
        "#{prefix}#{highlighter.apply(body)}#{suffix}"
      else
        if leftmost.negative?
          line_body[0, (index + surface.size + context_length_after)]
        else
          line_body[leftmost, (context_length_before + surface.size + context_length_after)]
        end
      end
    end

    def items_to_text(items, excerpt_context_length, highlighter, &)
      report_items =
        items.map do |category, relevant_morphemes|
          subcategories = relevant_morphemes.map { |m| yield m }
          item_heading =
            "* #{category}: " +
              subcategories.tally.map { |h, count| "#{h} (#{count})" }.join(" | ")
          subitems =
            relevant_morphemes.map do |m|
              source_name = m.line.source_name
              line_number = m.line.index + 1
              character_number = m.index_in_source_string + 1
              subcategory = yield m
              excerpt = excerpt(m, excerpt_context_length, highlighter)
              "  - " +
                [source_name,
                 "L#{line_number}, C#{character_number}",
                 subcategory,
                 excerpt].compact.join("\t")
            end
          [item_heading, subitems.join("\n")].join("\n")
        end
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

    def items_to_markdown(items, excerpt_context_length, highlighter, &)
      report_items =
        items.map do |category, relevant_morphemes|
          subcategories = relevant_morphemes.map { |m| yield m }
          item_heading =
            "* #{category}: " +
              subcategories.tally.map { |h, count| "#{h} (#{count})" }.join(" | ")
          subitems =
            relevant_morphemes.map do |m|
              source_name = m.line.source_name
              excerpt = excerpt(m, excerpt_context_length, highlighter)
              excerpt_md = "#{markup_as_markdown_inline_code(excerpt)}"
              "  - " + [source_name, excerpt_md].compact.join(": ")
            end
          [item_heading, subitems.join("\n")].join("\n")
        end
      report_items.join("\n")
    end

    def items_to_tsv(items, excerpt_context_length, highlighter, header, &)
      report_lines =
        items.map do |category, relevant_morphemes|
          relevant_morphemes.map do |m|
            source_name = m.line.source_name
            line_number = m.line.index + 1
            character_number = m.index_in_source_string + 1
            subcategory = yield m
            excerpt = excerpt(m, excerpt_context_length, highlighter)
            [category, source_name, line_number, character_number, subcategory, m.surface, excerpt]
              .map(&.to_s.gsub(TSV_ESCAPE_REGEX, TSV_ESCAPE)).join("\t")
          end
        end
      [header, report_lines.flatten.join("\n")].join("\n")
    end

    def report_variants(format, excerpt_context_length, sort_order, highlighter, header, exclude_ascii_only_items)
      items = variants(@lines, @yomi_parser, sort_order, exclude_ascii_only_items)
      case format
      in ReportFormat::Text
        items_to_text(items, excerpt_context_length, highlighter) do |morpheme|
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
        end
      in ReportFormat::Markdown
        items_to_markdown(items, excerpt_context_length, highlighter) do |morpheme|
          surface = morpheme.surface
          if ASCII_WORD_REGEX.match surface
            surface
          else
            morpheme.feature.lexical_form
          end
        end
      in ReportFormat::TSV
        items_to_tsv(items, excerpt_context_length, highlighter, header: header) do |morpheme|
          surface = morpheme.surface
          if ASCII_WORD_REGEX.match surface
            surface
          else
            morpheme.feature.lexical_form
          end
        end
      end
    end

    def report_heteronyms(format, excerpt_context_length, sort_order, highlighter, header, exclude_ascii_only_items)
      items = heteronyms(@lines, sort_order, exclude_ascii_only_items)
      case format
      in ReportFormat::Text
        items_to_text(items, excerpt_context_length, highlighter) do |morpheme|
          morpheme.feature.yomi # categorize subitems by yomi
        end
      in ReportFormat::Markdown
        items_to_markdown(items, excerpt_context_length, highlighter) do |morpheme|
          morpheme.feature.yomi # categorize subitems by yomi
        end
      in ReportFormat::TSV
        items_to_tsv(items, excerpt_context_length, highlighter, header: header) do |morpheme|
          morpheme.feature.yomi # categorize subitems by yomi
        end
      end
    end

    def report(type = ReportType::Variants, format = ReportFormat::Text,
               excerpt_context_length = 5, sort_order = SortOrder::Alphabetical,
               highlighter = nil, header = nil, exclude_ascii_only_items = false)
      # FIXME: the application somehow slows down if we do not use
      # conditionals (case..when) and unify invocations of the same methods
      # (e.g. report_variants(format, excerpt_context_length, sort_order, highlighter, header))
      case type
      in ReportType::Variants
        case format
        in ReportFormat::Text
        in ReportFormat::Markdown
        in ReportFormat::TSV
          header ||= TSV_HEADER_VARIANTS
        end
        report_variants(format, excerpt_context_length, sort_order, highlighter, header, exclude_ascii_only_items)
      in ReportType::Heteronyms
        case format
        in ReportFormat::Text
        in ReportFormat::Markdown
        in ReportFormat::TSV
          header ||= TSV_HEADER_HETERONYMS
        end
        report_heteronyms(format, excerpt_context_length, sort_order, highlighter, header, exclude_ascii_only_items)
      end
    end
  end
end
