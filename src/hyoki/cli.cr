module Hyoki
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
        exclude_ascii_only_items: true,
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

      parser = OptionParser.new do |o|
        o.summary_width = 24
        o.banner = <<-EOS
          Hyoki helps finding variants in Japanese text

          Usage:
            #{PROGRAM_NAME} [OPTIONS]... [FILE]...

          Options:
          EOS
        o.on("--report-type=TYPE", <<-EOS.chomp) do |s|
          Choose report type
          (#{Document::ReportType.names.map(&.downcase).join("|")}) \
          (default: #{c.report_type.to_s.downcase})
          EOS
          c.report_type =
            case s
            when "variants"   then Document::ReportType::Variants
            when "heteronyms" then Document::ReportType::Heteronyms
            else                   raise "Invalid report type: #{s.inspect}"
            end
        end
        o.on("--report-format=FORMAT", <<-EOS.chomp) do |s|
          Choose report format
          (#{Document::ReportFormat.names.map(&.downcase).join("|")}) \
          (default: #{c.report_format.to_s.downcase})
          EOS
          c.report_format =
            case s
            when "text"     then Document::ReportFormat::Text
            when "markdown" then Document::ReportFormat::Markdown
            when "tsv"      then Document::ReportFormat::TSV
            else                 raise "Invalid report format: #{s.inspect}"
            end
        end
        o.on("--highlight=WHEN", <<-EOS.chomp) do |s|
          Enable/disable excerpt highlighting
          (#{Highlight.names.map(&.downcase).join("|")}) \
          (default: #{c.highlight.to_s.downcase})
          EOS
          c.highlight =
            case s
            when "auto"   then Highlight::Auto
            when "always" then Highlight::Always
            when "never"  then Highlight::Never
            else               raise "Invalid value for highlight: #{s.inspect}"
            end
        end
        o.on("--excerpt-context-length=N|N,M", <<-EOS.chomp) do |s|
          Set excerpt context length to N characters
          (or preceding N and succeeding M) \
          (default: #{c.excerpt_context_length})
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
        end
        o.on("--sort-order=HOW", <<-EOS.chomp) do |s|
          Specify how report items should be sorted
          (#{Document::SortOrder.names.map(&.downcase).join("|")}) \
          (default: #{c.sort_order.to_s.downcase})
          EOS
          c.sort_order =
            case s
            when "alphabetical" then Document::SortOrder::Alphabetical
            when "appearance"   then Document::SortOrder::Appearance
            else                     raise "Invalid value for sort_order: #{s.inspect}"
            end
        end
        o.on("--exclude-ascii-only-items=BOOL", <<-EOS.chomp) do |s|
          Exclude ASCII-only items in the output
          (true|false) (default: #{c.exclude_ascii_only_items})
          EOS
          c.exclude_ascii_only_items =
            case s
            when "true"  then true
            when "false" then false
            else              raise "Invalid value for exclude_ascii_only_items: #{s.inspect}"
            end
        end
        o.on("--pager=PAGER", <<-EOS.chomp) do |s|
          Specify pager
          (default: #{c.pager.to_s.inspect}; falls back to $HYOKI_PAGER or $PAGER)
          EOS
          c.pager = s if s && !s.empty?
        end
        o.on("--mecab-dict-dir=DIR", <<-EOS.chomp) do |s|
          Specify MeCab dictionary directory
          (e.g. /var/lib/mecab/dic/ipadic-utf8)
          EOS
          c.mecab_dict_dir =
            case
            when !(Dir.exists? s)          then raise "Directory not found: #{s.inspect}"
            when !(File::Info.readable? s) then raise "Directory not readable: #{s.inspect}"
            else                                s
            end
        end
        o.on("--help", "Show help message") { c.show_help = true }
        o.on("--version", "Show version") { c.show_version = true }
      end
      parser.parse

      if c.show_help
        puts parser
        exit 0
      end

      if c.show_version
        puts_or_print Hyoki::VERSION
        exit 0
      end

      highlighter =
        case c.highlight
        in Highlight::Auto   then STDOUT.tty? ? Document::Highlighter.new : nil
        in Highlight::Always then Document::Highlighter.new
        in Highlight::Never  then nil
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
              highlighter: highlighter,
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
