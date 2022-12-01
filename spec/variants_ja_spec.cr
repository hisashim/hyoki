require "./spec_helper"
require "semantic_version"

describe "VariantsJa" do
  it "has valid version" do
    SemanticVersion.parse(VariantsJa::VERSION).is_a? SemanticVersion
  end

  describe "Morpheme" do
    describe "#surface" do
      it "returns surface" do
        input = <<-EOS
          私の名前は中野です。
          EOS
        VariantsJa::Document.new(input).lines[0].morphemes.map { |m| m.surface }
          .should eq ["私", "の", "名前", "は", "中野", "です", "。"]
      end
    end

    describe "#line_index" do
      it "returns the index of the line to which the morpheme belongs" do
        input = <<-EOS
          L1
          L2
          EOS
        VariantsJa::Document.new(input).lines[0].morphemes[0].line_index.should eq 0
        VariantsJa::Document.new(input).lines[1].morphemes[0].line_index.should eq 1
      end
    end

    describe "#index" do
      it "returns the morpheme index" do
        input = <<-EOS
          L1M1 L1M2
          L2M1 L2M2
          EOS
        VariantsJa::Document.new(input).lines[0].morphemes[0].index.should eq 0
        VariantsJa::Document.new(input).lines[0].morphemes[1].index.should eq 1
        VariantsJa::Document.new(input).lines[1].morphemes[0].index.should eq 0
        VariantsJa::Document.new(input).lines[1].morphemes[1].index.should eq 1
      end
    end

    describe "#string_indexes" do
      it "returns the indexes (start position) of all occurences of the substring" do
        input = <<-EOS
          する・しない・する・しない・する・しない
          EOS
        line = VariantsJa::Document.new(input).lines[0]
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
        lines = VariantsJa::Document.new(input).lines
        lines[0].morphemes[0].string_index.should eq 0
        lines[0].morphemes[5].string_index.should eq 7
        lines[0].morphemes[10].string_index.should eq 14
      end

      it "handles empty input without problems" do
        input = <<-EOS.chomp
          EOS
        VariantsJa::Document.new(input).lines.each { |l|
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
          morphemes = VariantsJa::Document.new(input).lines[0].morphemes
          morphemes[0].feature.yomi.should eq "シコウ"
          morphemes[2].feature.yomi.should eq "シコウ"
        end
      end

      describe "#lexical_form" do
        it "returns lexical form of the morpheme" do
          input = <<-EOS
            わかりません。
            EOS
          morphemes = VariantsJa::Document.new(input).lines[0].morphemes
          morphemes[0].feature.lexical_form.should eq "わかる"
          morphemes[1].feature.lexical_form.should eq "ます"
        end
      end
    end
  end

  describe "Document" do
    describe "#string_to_morphemes" do
      it "converts string to morphemes" do
        input = <<-EOS
          わかりません。
          EOS
        morphemes = VariantsJa.string_to_morphemes(input, 0, Fucoidan::Fucoidan.new)
        morphemes.map { |m| m.surface }.should eq ["わかり", "ませ", "ん", "。"]
      end
    end

    describe "#yomi" do
      it "returns yomi of the string" do
        input = <<-EOS
          日本語
          EOS
        VariantsJa.yomi(input, Fucoidan::Fucoidan.new("-Oyomi")).should eq "ニホンゴ"
      end
    end

    describe "#report_variants_text" do
      it "returns report on variants in text format" do
        input = <<-EOS
          流れよわが涙、と警官は言った。
          そういうことがあるのだという。
          EOS
        doc = VariantsJa::Document.new(input)
        doc.report_variants_text.should eq <<-EOS.chomp
          イウ: 言う (1) | いう (1)
          \tL1, C12\t、と警官は言った。
          \tL2, C13\tあるのだという。
          EOS
      end

      it "returns report with specified length of context" do
        input = <<-EOS
          流れよわが涙、と警官は言った。
          そういうことがあるのだという。
          EOS
        doc = VariantsJa::Document.new(input)
        doc.report_variants_text(context_before: 0, context_after: 0)
          .should eq <<-EOS.chomp
            イウ: 言う (1) | いう (1)
            \tL1, C12\t言っ
            \tL2, C13\tいう
            EOS
        doc.report_variants_text(context_before: 3, context_after: 3)
          .should eq <<-EOS.chomp
            イウ: 言う (1) | いう (1)
            \tL1, C12\t警官は言った。
            \tL2, C13\tのだという。
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
        doc = VariantsJa::Document.new(input)
        doc.report_variants_text.should eq <<-EOS.chomp
          シコウ: 志向 (1) | 思考 (1) | 指向 (1) | 施行 (1) | 試行 (1)
          \tL1, C1\t志向
          \tL2, C1\t思考
          \tL3, C1\t指向
          \tL4, C1\t施行
          \tL5, C1\t試行
          EOS
      end

      it "returns report sorted when named arg sort is specified" do
        input = <<-EOS
          思考と試行。意思と意志。
          EOS
        doc = VariantsJa::Document.new(input)
        doc.report_variants_text(sort_order: :alphabetical).should eq <<-EOS.chomp
          イシ: 意思 (1) | 意志 (1)
          \tL1, C7\t考と試行。意思と意志。
          \tL1, C10\t行。意思と意志。
          シコウ: 思考 (1) | 試行 (1)
          \tL1, C1\t思考と試行。意
          \tL1, C4\t思考と試行。意思と意
          EOS
        doc.report_variants_text(sort_order: :appearance).should eq <<-EOS.chomp
          シコウ: 思考 (1) | 試行 (1)
          \tL1, C1\t思考と試行。意
          \tL1, C4\t思考と試行。意思と意
          イシ: 意思 (1) | 意志 (1)
          \tL1, C7\t考と試行。意思と意志。
          \tL1, C10\t行。意思と意志。
          EOS
      end
    end

    describe "#report_variants_tsv" do
      it "returns report in TSV format" do
        input = <<-EOS
          流れよわが涙、と警官は言った。
          そういうことがあるのだという。
          EOS
        doc = VariantsJa::Document.new(input)
        doc.report_variants_tsv.should eq <<-EOS.chomp
          lexical form yomi\tline\tcharacter\tlexical form\tsurface\texcerpt
          イウ\t1\t12\t言う\t言っ\t、と警官は言った。
          イウ\t2\t13\tいう\tいう\tあるのだという。
          EOS
      end

      it "returns report sorted when named arg sort is specified" do
        input = <<-EOS
          思考と試行。意思と意志。
          EOS
        doc = VariantsJa::Document.new(input)
        doc.report_variants_tsv(sort_order: :alphabetical).should eq <<-EOS.chomp
          lexical form yomi\tline\tcharacter\tlexical form\tsurface\texcerpt
          イシ\t1\t7\t意思\t意思\t考と試行。意思と意志。
          イシ\t1\t10\t意志\t意志\t行。意思と意志。
          シコウ\t1\t1\t思考\t思考\t思考と試行。意
          シコウ\t1\t4\t試行\t試行\t思考と試行。意思と意
          EOS
        doc.report_variants_tsv(sort_order: :appearance).should eq <<-EOS.chomp
          lexical form yomi\tline\tcharacter\tlexical form\tsurface\texcerpt
          シコウ\t1\t1\t思考\t思考\t思考と試行。意
          シコウ\t1\t4\t試行\t試行\t思考と試行。意思と意
          イシ\t1\t7\t意思\t意思\t考と試行。意思と意志。
          イシ\t1\t10\t意志\t意志\t行。意思と意志。
          EOS
      end
    end
  end
end
