# frozen_string_literal: true

require "tmpdir"

require_relative "../../lib/fretboard/database"

RSpec.describe Fretboard::Database do
  # A tiny fixture rather than the real data/chords.txt: it exercises the
  # same blank-line-separated block format (name line, then "x"-for-muted
  # fingering lines) without depending on the shipped chord set's contents.
  FIXTURE = <<~CHORDS
    A
    x 0 2 2 2 0
    5 7 7 6 5 5

    Am
    x 0 2 2 1 0
  CHORDS

  around do |example|
    Dir.mktmpdir do |dir|
      @path = File.join(dir, "chords.txt")
      File.write(@path, FIXTURE)
      example.run
    end
  end

  subject(:database) { described_class.new(path: @path) }

  describe "#chords" do
    it "parses one entry per blank-line-separated block" do
      expect(database.chords.map(&:name)).to eq(%w[A Am])
    end

    it "parses each fingering line into muted/open/fretted values" do
      expect(database.chords.first.positions).to eq([
        [nil, 0, 2, 2, 2, 0],
        [5, 7, 7, 6, 5, 5],
      ])
    end
  end

  describe "#chord_from_name" do
    it "finds a chord case-insensitively" do
      expect(database.chord_from_name("a").name).to eq("A")
      expect(database.chord_from_name("AM").name).to eq("Am")
    end

    it "is nil for a name with no entry" do
      expect(database.chord_from_name("zz")).to be_nil
    end
  end

  describe "#name_from_chord" do
    it "finds the name for a stored fingering" do
      expect(database.name_from_chord([nil, 0, 2, 2, 1, 0])).to eq("Am")
    end

    it "is nil for a fingering that is not stored" do
      expect(database.name_from_chord([0, 0, 0, 0, 0, 2])).to be_nil
    end
  end

  describe "#positions_from_name" do
    it "lists every fingering of a stored name" do
      expect(database.positions_from_name("A")).to eq([
        [nil, 0, 2, 2, 2, 0],
        [5, 7, 7, 6, 5, 5],
      ])
    end

    it "is empty for a name with no entry" do
      expect(database.positions_from_name("zz")).to eq([])
    end
  end
end
