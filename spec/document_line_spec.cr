require "spec"
require "../src/hyoki/document/line"

describe "Hyoki" do
  describe "Document" do
    describe "Line" do
      describe ".string_indexes" do
        it "returns the indexes (start position) of all occurences of the substring" do
          input = <<-EOS
            する・しない・する・しない・する・しない
            EOS
          Hyoki::Document::Line.string_indexes(input, "する").should eq [0, 7, 14]
        end
      end

      describe ".string_to_morphemes" do
        it "converts string to morphemes" do
          input = <<-EOS
            わかりません。
            EOS
          parser = Fucoidan::Fucoidan.new
          line = Hyoki::Document::Line.new(input, 0, parser)
          Hyoki::Document::Line.string_to_morphemes(input, line, parser).map(&.surface)
            .should eq ["わかり", "ませ", "ん", "。"]
        end
      end
    end
  end
end
