require "./spec_helper"
require "semantic_version"

describe VariantsJa do
  it "has valid version" do
    SemanticVersion.parse(VariantsJa::VERSION).is_a? SemanticVersion
  end
end
