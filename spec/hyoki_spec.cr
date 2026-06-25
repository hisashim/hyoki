require "spec"
require "../src/hyoki"
require "semantic_version"

describe "Hyoki" do
  it "has valid version" do
    SemanticVersion.parse(Hyoki::VERSION).is_a? SemanticVersion
  end
end
