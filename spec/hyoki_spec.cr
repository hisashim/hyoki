require "./spec_helper"
require "semantic_version"

describe "Hyoki" do
  it "has valid version" do
    SemanticVersion.parse(Hyoki::VERSION).is_a? SemanticVersion
  end

  describe "Morpheme" do
    describe "#surface" do
      it "returns surface" do
        input = <<-EOS
          私の名前は中野です。
          EOS
        Hyoki::Document.new(input).lines[0].morphemes.map { |m| m.surface }
          .should eq ["私", "の", "名前", "は", "中野", "です", "。"]
      end
    end

    describe "#line" do
      it "returns the line to which the morpheme belongs" do
        input = <<-EOS
          L1
          L2
          EOS
        Hyoki::Document.new(input).lines[0].morphemes[0].line.index.should eq 0
        Hyoki::Document.new(input).lines[1].morphemes[0].line.index.should eq 1
      end
    end

    describe "#index" do
      it "returns the morpheme index" do
        input = <<-EOS
          L1M1 L1M2
          L2M1 L2M2
          EOS
        Hyoki::Document.new(input).lines[0].morphemes[0].index.should eq 0
        Hyoki::Document.new(input).lines[0].morphemes[1].index.should eq 1
        Hyoki::Document.new(input).lines[1].morphemes[0].index.should eq 0
        Hyoki::Document.new(input).lines[1].morphemes[1].index.should eq 1
      end
    end

    describe "#string_indexes" do
      it "returns the indexes (start position) of all occurences of the substring" do
        input = <<-EOS
          する・しない・する・しない・する・しない
          EOS
        line = Hyoki::Document.new(input).lines[0]
        morphemes = line.morphemes
        m0 = morphemes[0]
        m0.surface.should eq "する"
        m0.string_indexes(line.body, m0.surface).should eq [0, 7, 14]
      end
    end

    describe "#string_index" do
      it "returns the index of the surface as a substring in the source text" do
        input = <<-EOS
          する・しない・する・しない・する・しない
          そういうことが あるのだという。
          EOS
        lines = Hyoki::Document.new(input).lines
        lines[0].morphemes[0].string_index.should eq 0
        lines[0].morphemes[5].string_index.should eq 7
        lines[0].morphemes[10].string_index.should eq 14
      end

      it "works correctly for very long input" do
        # this input consists of 1000 morphemes, and morphemes[0]
        # starts at input[1] because of the preceding space
        input = " " + ("0あ1い2う3え4お5か6き7く8け9こ" * 50)
        lines = Hyoki::Document.new(input).lines
        lines[0].morphemes[0].string_index.should eq 1
        lines[0].morphemes[100].string_index.should eq 101
        lines[0].morphemes[990].string_index.should eq 991
      end

      it "handles empty input without problems" do
        input = <<-EOS.chomp
          EOS
        Hyoki::Document.new(input).lines.each { |l|
          l.morphemes.each { |m|
            substring_start = m.string_index
            substring_length = m.surface.size
            substring = l.body[substring_start, substring_length]
            substring.should eq m.surface
          }
        }
      end
    end

    describe "Feature" do
      describe "#yomi" do
        it "returns yomi of the morpheme" do
          input = <<-EOS
            思考と試行。
            EOS
          morphemes = Hyoki::Document.new(input).lines[0].morphemes
          morphemes[0].feature.yomi.should eq "シコウ"
          morphemes[2].feature.yomi.should eq "シコウ"
        end
      end

      describe "#lexical_form" do
        it "returns lexical form of the morpheme" do
          input = <<-EOS
            わかりません。
            EOS
          morphemes = Hyoki::Document.new(input).lines[0].morphemes
          morphemes[0].feature.lexical_form.should eq "わかる"
          morphemes[1].feature.lexical_form.should eq "ます"
        end
      end
    end
  end

  describe "Document" do
    describe ".new" do
      it "receives Array(IO) as its sources" do
        input = [IO::Memory.new("S1\n"), IO::Memory.new("S2")]
        lines = Hyoki::Document.new(input).lines
        lines.map { |l| [l.body, l.eol] }.should eq [["S1", "\n"], ["S2", nil]]
      end

      it "receives Array(File) as its sources" do
        tempfiles = [
          File.tempfile("f1", ".txt") { |f| f.print("F1\n") },
          File.tempfile("f2", ".txt") { |f| f.print("F2") },
        ]
        input = tempfiles.map { |f| File.open(f.path) }
        lines = Hyoki::Document.new(input).lines
        tempfiles.map &.delete
        lines.map { |l| [l.body, l.eol] }.should eq [["F1", "\n"], ["F2", nil]]
      end

      it "receives String as its source" do
        input = "Lipsum.\n"
        lines = Hyoki::Document.new(input).lines
        lines.map { |l| [l.body, l.eol] }.should eq [["Lipsum.", "\n"]]
      end
    end

    describe "#lines" do
      it "returns lines" do
        input = <<-EOS
          L1
          L2
          EOS
        lines = Hyoki::Document.new(input).lines
        lines.map { |l| [l.body, l.eol] }.should eq [["L1", "\n"], ["L2", nil]]
      end
    end

    describe "#string_to_morphemes" do
      it "converts string to morphemes" do
        input = <<-EOS
          わかりません。
          EOS
        parser = Fucoidan::Fucoidan.new
        line = Hyoki::Document::Line.new(input, 0, parser)
        morphemes = Hyoki.string_to_morphemes(input, line, parser)
        morphemes.map { |m| m.surface }.should eq ["わかり", "ませ", "ん", "。"]
      end
    end

    describe "#yomi" do
      it "returns yomi of the string" do
        input = <<-EOS
          日本語
          EOS
        Hyoki.yomi(input, Fucoidan::Fucoidan.new("-Oyomi")).should eq "ニホンゴ"
      end
    end

    describe "#report_variants_text" do
      it "returns report on variants in text format" do
        input = <<-EOS
          流れよわが涙、と警官は言った。
          そういうことがあるのだという。
          EOS
        doc = Hyoki::Document.new(input)
        doc.report_variants_text.should eq <<-EOS.chomp
          ## イウ: 言う (1) | いう (1)
              L1, C12\t言う\t、と警官は言った。
              L2, C13\tいう\tあるのだという。
          EOS
      end

      it "returns report with specified length of context" do
        input = <<-EOS
          流れよわが涙、と警官は言った。
          そういうことがあるのだという。
          EOS
        doc = Hyoki::Document.new(input)
        doc.report_variants_text(context: 0)
          .should eq <<-EOS.chomp
            ## イウ: 言う (1) | いう (1)
                L1, C12\t言う\t言っ
                L2, C13\tいう\tいう
            EOS
        doc.report_variants_text(context: {3, 3})
          .should eq <<-EOS.chomp
            ## イウ: 言う (1) | いう (1)
                L1, C12\t言う\t警官は言った。
                L2, C13\tいう\tのだという。
            EOS
      end

      it "returns report with highlighting when color is true" do
        input = <<-EOS
          流れよわが涙、と警官は言った。
          そういうことがあるのだという。
          EOS
        doc = Hyoki::Document.new(input)
        doc.report_variants_text(color: true).should eq <<-EOS.chomp
          ## イウ: 言う (1) | いう (1)
              L1, C12\t言う\t、と警官は\e[1;4;7m言っ\e[0mた。
              L2, C13\tいう\tあるのだと\e[1;4;7mいう\e[0m。
          EOS
      end

      it "returns report on variants, without context if none" do
        input = <<-EOS
          志向
          思考
          指向
          施行
          試行
          EOS
        doc = Hyoki::Document.new(input)
        doc.report_variants_text.should eq <<-EOS.chomp
          ## シコウ: 志向 (1) | 思考 (1) | 指向 (1) | 施行 (1) | 試行 (1)
              L1, C1\t志向\t志向
              L2, C1\t思考\t思考
              L3, C1\t指向\t指向
              L4, C1\t施行\t施行
              L5, C1\t試行\t試行
          EOS
      end

      it "returns report sorted when named arg sort is specified" do
        input = <<-EOS
          思考と試行。意思と意志。
          EOS
        doc = Hyoki::Document.new(input)
        doc.report_variants_text(sort: :alphabetical).should eq <<-EOS.chomp
          ## イシ: 意思 (1) | 意志 (1)
              L1, C7\t意思\t考と試行。意思と意志。
              L1, C10\t意志\t行。意思と意志。
          ## シコウ: 思考 (1) | 試行 (1)
              L1, C1\t思考\t思考と試行。意
              L1, C4\t試行\t思考と試行。意思と意
          EOS
        doc.report_variants_text(sort: :appearance).should eq <<-EOS.chomp
          ## シコウ: 思考 (1) | 試行 (1)
              L1, C1\t思考\t思考と試行。意
              L1, C4\t試行\t思考と試行。意思と意
          ## イシ: 意思 (1) | 意志 (1)
              L1, C7\t意思\t考と試行。意思と意志。
              L1, C10\t意志\t行。意思と意志。
          EOS
      end

      it "uses yomi of lexical form iff surface differs from lexical form" do
        input = <<-EOS
          区切り方のほう。区切りかたの方。
          云う。言った。
          EOS
        doc = Hyoki::Document.new(input)
        doc.report_variants_text.should eq <<-EOS.chomp
          ## イウ: 云う (1) | 言う (1)
              L2, C1\t云う\t云う。言った。
              L2, C4\t言う\t云う。言った。
          ## カタ: 方 (1) | かた (1)
              L1, C4\t方\t区切り方のほう。区
              L1, C12\tかた\tう。区切りかたの方。
          ## ホウ: ほう (1) | 方 (1)
              L1, C6\tほう\t区切り方のほう。区切りか
              L1, C15\t方\t切りかたの方。
          EOS
      end

      it "detects case variants of words in ASCII" do
        input = <<-EOS
          UNIXとUnix。
          EOS
        doc = Hyoki::Document.new(input)
        doc.report_variants_text.should eq <<-EOS.chomp
          ## unix: UNIX (1) | Unix (1)
              L1, C1\tUNIX\tUNIXとUnix
              L1, C6\tUnix\tUNIXとUnix。
          EOS
      end

      it "can not yet detect variants of ASCII words in general" do
        input = <<-EOS
          UNIXとUnix。Greyとgray。Colorとcolour。
          EOS
        doc = Hyoki::Document.new(input)
        doc.report_variants_text.should eq <<-EOS.chomp
          ## unix: UNIX (1) | Unix (1)
              L1, C1\tUNIX\tUNIXとUnix
              L1, C6\tUnix\tUNIXとUnix。Grey
          EOS
      end

      context "input is from multiple files" do
        it "shows corresponding source file names" do
          sources = <<-EOS.lines(chomp: false)
            流れよわが涙、と警官は言った。
            そういうことがあるのだという。
            言われてみればそのとおりだ。
            EOS
          files = sources.map { |s| File.tempfile { |f| f.print(s) } }
            .map { |f| File.open(f.path) }
          doc = Hyoki::Document.new(files)
          doc.report_variants_text.should eq <<-EOS.chomp
            ## イウ: 言う (2) | いう (1)
                #{files[0].path}\tL1, C12\t言う\t、と警官は言った。
                #{files[1].path}\tL1, C13\tいう\tあるのだという。
                #{files[2].path}\tL1, C1\t言う\t言われてみれば
            EOS
          files.each &.delete
        end
      end

      context "input is from non-file stream (e.g. ARGF, STDIN)" do
        it "omits source file names" do
          input = <<-EOS
            流れよわが涙、と警官は言った。
            そういうことがあるのだという。
            言われてみればそのとおりだ。
            EOS
          doc = Hyoki::Document.new(input)
          doc.report_variants_text.should eq <<-EOS.chomp
            ## イウ: 言う (2) | いう (1)
                L1, C12\t言う\t、と警官は言った。
                L2, C13\tいう\tあるのだという。
                L3, C1\t言う\t言われてみれば
            EOS
        end
      end
    end

    describe "#report_variants_tsv" do
      it "returns report in TSV format" do
        input = <<-EOS
          流れよわが涙、と警官は言った。
          そういうことがあるのだという。
          EOS
        doc = Hyoki::Document.new(input)
        doc.report_variants_tsv.should eq <<-EOS.chomp
          lexical form yomi\tsource\tline\tcharacter\tlexical form\tsurface\texcerpt
          イウ\t\t1\t12\t言う\t言っ\t、と警官は言った。
          イウ\t\t2\t13\tいう\tいう\tあるのだという。
          EOS
      end

      it "returns report with highlighting when color is true" do
        input = <<-EOS
          流れよわが涙、と警官は言った。
          そういうことがあるのだという。
          EOS
        doc = Hyoki::Document.new(input)
        doc.report_variants_tsv(color: true).should eq <<-EOS.chomp
          lexical form yomi\tsource\tline\tcharacter\tlexical form\tsurface\texcerpt
          イウ\t\t1\t12\t言う\t言っ\t、と警官は\e[1;4;7m言っ\e[0mた。
          イウ\t\t2\t13\tいう\tいう\tあるのだと\e[1;4;7mいう\e[0m。
          EOS
      end

      it "returns report sorted when named arg sort is specified" do
        input = <<-EOS
          思考と試行。意思と意志。
          EOS
        doc = Hyoki::Document.new(input)
        doc.report_variants_tsv(sort: :alphabetical).should eq <<-EOS.chomp
          lexical form yomi\tsource\tline\tcharacter\tlexical form\tsurface\texcerpt
          イシ\t\t1\t7\t意思\t意思\t考と試行。意思と意志。
          イシ\t\t1\t10\t意志\t意志\t行。意思と意志。
          シコウ\t\t1\t1\t思考\t思考\t思考と試行。意
          シコウ\t\t1\t4\t試行\t試行\t思考と試行。意思と意
          EOS
        doc.report_variants_tsv(sort: :appearance).should eq <<-EOS.chomp
          lexical form yomi\tsource\tline\tcharacter\tlexical form\tsurface\texcerpt
          シコウ\t\t1\t1\t思考\t思考\t思考と試行。意
          シコウ\t\t1\t4\t試行\t試行\t思考と試行。意思と意
          イシ\t\t1\t7\t意思\t意思\t考と試行。意思と意志。
          イシ\t\t1\t10\t意志\t意志\t行。意思と意志。
          EOS
      end
    end

    describe "#report_heteronyms_text" do
      it "returns report on variants in text format" do
        input = <<-EOS
          区切り方がわかりません。区切りかたがわかりません。
          その方がいいでしょう。そのほうがいいでしょう。
          EOS
        doc = Hyoki::Document.new(input)
        doc.report_heteronyms_text.should eq <<-EOS.chomp
          ## 方: カタ (1) | ホウ (1)
              L1, C4\tカタ\t区切り方がわかりま
              L2, C3\tホウ\tその方がいいでし
          EOS
      end
    end

    describe "#report_heteronyms_tsv" do
      it "returns report in TSV format" do
        input = <<-EOS
          区切り方がわかりません。区切りかたがわかりません。
          その方がいいでしょう。そのほうがいいでしょう。
          EOS
        doc = Hyoki::Document.new(input)
        doc.report_heteronyms_tsv.should eq <<-EOS.chomp
          surface\tsource\tline\tcharacter\tyomi\tsurface\texcerpt
          方\t\t1\t4\tカタ\t方\t区切り方がわかりま
          方\t\t2\t3\tホウ\t方\tその方がいいでし
          EOS
      end
    end
  end
end
