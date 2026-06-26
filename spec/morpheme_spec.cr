require "spec"
require "../src/hyoki/morpheme"

# returns lines from string
def lines(string, parser = Fucoidan::Fucoidan.new, source_io = nil)
  string.scan(Hyoki::Document::Line::LINE_REGEX).map do |md|
    md[0]
  end.map_with_index do |str, i|
    Hyoki::Document::Line.new(str, i, parser, source_io: source_io)
  end
end

describe "Hyoki" do
  describe "Morpheme" do
    describe "#surface" do
      it "returns surface" do
        input = <<-EOS
          私の名前は中野です。
          EOS
        lines(input).first.morphemes.map(&.surface)
          .should eq ["私", "の", "名前", "は", "中野", "です", "。"]
      end
    end

    describe "#line" do
      it "returns the line to which the morpheme belongs" do
        input = <<-EOS
          L1
          L2
          EOS
        # FIXME: tautology
        lines(input)[0].morphemes[0].line.index.should eq 0
        lines(input)[1].morphemes[0].line.index.should eq 1
      end
    end

    describe "#index" do
      it "returns the morpheme index" do
        input = <<-EOS
          L1M1 L1M2
          L2M1 L2M2
          EOS
        lines(input)[0].morphemes[0].index.should eq 0
        lines(input)[0].morphemes[1].index.should eq 1
        lines(input)[1].morphemes[0].index.should eq 0
        lines(input)[1].morphemes[1].index.should eq 1
      end
    end

    describe "#index_in_source_string" do
      it "returns the index of the surface as a substring in the source text" do
        input = <<-EOS
          する・しない・する・しない・する・しない
          そういうことが あるのだという。
          EOS
        lines(input)[0].morphemes[0].index_in_source_string.should eq 0
        lines(input)[0].morphemes[5].index_in_source_string.should eq 7
        lines(input)[0].morphemes[10].index_in_source_string.should eq 14
        lines(input)[1].morphemes[0].index_in_source_string.should eq 0
        lines(input)[1].morphemes[4].index_in_source_string.should eq 10
        lines(input)[1].morphemes[8].index_in_source_string.should eq 15
      end

      it "works correctly for very long input" do
        input = " " + ("0あ1い2う3え4お5か6き7く8け9こ" * 50)
        lines(input)[0].morphemes[0].index_in_source_string.should eq 1
        lines(input)[0].morphemes[100].index_in_source_string.should eq 101
        lines(input)[0].morphemes[990].index_in_source_string.should eq 991
      end

      it "handles empty input without problems" do
        input = <<-EOS.chomp
          EOS
        lines(input).each do |l|
          l.morphemes.each do |m|
            substring_start = m.index_in_source_string
            substring_length = m.surface.size
            substring = l.body[substring_start, substring_length]
            substring.should eq m.surface
          end
        end
      end
    end

    describe "Feature" do
      describe "#yomi" do
        it "returns yomi of the morpheme" do
          input = <<-EOS
            思考と試行。
            EOS
          morphemes = lines(input).first.morphemes
          morphemes[0].feature.yomi.should eq "シコウ"
          morphemes[2].feature.yomi.should eq "シコウ"
        end
      end

      describe "#lexical_form" do
        it "returns lexical form of the morpheme" do
          input = <<-EOS
            わかりません。
            EOS
          morphemes = lines(input).first.morphemes
          morphemes[0].feature.lexical_form.should eq "わかる"
          morphemes[1].feature.lexical_form.should eq "ます"
        end
      end
    end
  end
end
