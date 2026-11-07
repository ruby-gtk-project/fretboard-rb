# frozen_string_literal: true

require_relative "../../lib/fretboard/chord_name_algorithm"

RSpec.describe Fretboard::ChordNameAlgorithm do
  describe ".notes" do
    it "turns a fingering into semitones above A, skipping muted strings" do
      # Open low E is 7 semitones above A; fret 2 on the A string (index 1) is
      # 2 semitones above A; the muted D string (index 2) is dropped entirely.
      expect(described_class.notes([0, 2, nil, nil, nil, nil])).to eq([7, 2])
    end
  end

  describe ".calculate_chord_name" do
    it "names an open-position major chord" do
      # C major: x 3 2 0 1 0
      expect(described_class.calculate_chord_name([nil, 3, 2, 0, 1, 0])).to eq("C")
    end

    it "names a minor chord" do
      # A minor: x 0 2 2 1 0
      expect(described_class.calculate_chord_name([nil, 0, 2, 2, 1, 0])).to eq("Am")
    end

    it "falls back to a bass-note name when the lowest note is not the root" do
      # Dropping the lowest string (the muted-first comparison) exercises
      # chord_name_over_bass: a fingering not present in the table is
      # unreachable from the UI any other way than this algorithm.
      name = described_class.calculate_chord_name([0, 0, 0, 0, 0, 2])
      expect(name).to eq("Em11")
    end

    it "is nil when the interval set matches no known chord quality" do
      expect(described_class.calculate_chord_name([0, 1, nil, nil, nil, nil])).to be_nil
    end

    it "is nil when the fingering has no notes at all" do
      expect(described_class.calculate_chord_name([nil, nil, nil, nil, nil, nil])).to be_nil
    end
  end

  describe ".intervals" do
    it "reduces notes to sorted, deduplicated intervals above the root" do
      expect(described_class.intervals([0, 4, 7, 4], 0)).to eq([0, 4, 7])
    end

    it "wraps intervals below the root around the scale" do
      expect(described_class.intervals([10, 2], 10)).to eq([0, 4])
    end
  end
end
