# frozen_string_literal: true

require_relative "../../lib/fretboard/chord_ops"

RSpec.describe Fretboard::ChordOps do
  describe ".find_barre_length" do
    it "is 0 when fewer than two strings sit at fret 1" do
      expect(described_class.find_barre_length([nil, 0, 2, 2, 1, 0])).to eq(0)
    end

    it "counts the run of fret-1 strings from the high E down" do
      expect(described_class.find_barre_length([1, 1, 1, 1, 1, 1])).to eq(6)
    end

    it "stops the run at the first muted or open string" do
      # Scanned high E first: the open string two in from the top (index 3
      # once reversed) ends the run after three fret-1 strings are counted.
      expect(described_class.find_barre_length([1, 1, 0, 1, 1, 1])).to eq(3)
    end

    it "stops the run at a string past the end of the array" do
      expect(described_class.find_barre_length([1, 1])).to eq(2)
    end
  end

  describe ".lowest_fingered_fret" do
    it "is nil when nothing is fingered" do
      expect(described_class.lowest_fingered_fret([nil, nil, nil, nil, nil, nil])).to be_nil
    end

    it "is nil when every string is open" do
      expect(described_class.lowest_fingered_fret([0, 0, 0, 0, 0, 0])).to be_nil
    end

    it "is the lowest positive fret across the strings" do
      expect(described_class.lowest_fingered_fret([nil, 3, 2, 0, 1, 0])).to eq(1)
    end

    it "is always 1 for a special-case chord even when it reaches higher" do
      expect(described_class.lowest_fingered_fret([nil, 0, 2, 2, 2, 0])).to eq(1)
    end
  end

  describe ".adjust_chord" do
    it "leaves the chord alone at barre 0" do
      expect(described_class.adjust_chord([nil, 3, 2, 0, 1, 0], 0)).to eq([nil, 3, 2, 0, 1, 0])
    end

    it "shifts fingered frets down by barre - 1, leaving open and muted strings alone" do
      expect(described_class.adjust_chord([nil, 3, 2, 0, 1, 0], 2)).to eq([nil, 2, 1, 0, 0, 0])
    end
  end

  describe ".prettify_chord_name" do
    it "capitalises the root note" do
      expect(described_class.prettify_chord_name("c")).to eq("C")
    end

    it "turns a sharpenable # into the real sharp sign" do
      expect(described_class.prettify_chord_name("c#")).to eq("C♯")
    end

    it "turns a flattenable b into the real flat sign" do
      expect(described_class.prettify_chord_name("bb")).to eq("B♭")
    end

    it "spaces out word-like qualities" do
      expect(described_class.prettify_chord_name("cdim")).to eq("C dim")
      expect(described_class.prettify_chord_name("caug")).to eq("C aug")
      expect(described_class.prettify_chord_name("cmaj7")).to eq("C maj7")
    end

    it "capitalises the bass note after a slash" do
      expect(described_class.prettify_chord_name("fmaj7/c")).to eq("F maj7/C")
    end

    it "strips whitespace from the input" do
      expect(described_class.prettify_chord_name(" c m 7 ")).to eq("Cm7")
    end
  end

  describe ".serialize_chord_name" do
    it "is the inverse of prettify_chord_name for a simple chord" do
      expect(described_class.serialize_chord_name("C♯m7")).to eq("c#m7")
    end

    it "turns the flat sign back into b and lowercases everything" do
      expect(described_class.serialize_chord_name("B♭maj7")).to eq("bbmaj7")
    end

    it "strips whitespace" do
      expect(described_class.serialize_chord_name("C dim")).to eq("cdim")
    end
  end

  describe ".enharmonic_equivalent" do
    it "gives the flat spelling for a sharp root" do
      expect(described_class.enharmonic_equivalent("c#m7")).to eq("db")
    end

    it "gives the sharp spelling for a flat root" do
      expect(described_class.enharmonic_equivalent("dbmaj7")).to eq("c#")
    end

    it "is nil for a root with no enharmonic pair" do
      expect(described_class.enharmonic_equivalent("cm7")).to be_nil
    end
  end
end
