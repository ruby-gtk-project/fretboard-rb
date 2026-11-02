# frozen_string_literal: true

module Fretboard
  # Database is the built-in chord set.
  #
  # Ported from upstream's src/database.rs, and reads the same data file,
  # data/chords.txt. The file is a sequence of blank-line separated blocks: the
  # first line of a block is the chord's name, every following line is one
  # fingering, six whitespace-separated values from the low E up, where "x" is
  # a muted string.
  #
  # Upstream compiles the file into the binary with include_str! and scans it
  # in parallel with rayon; here it is read from the installed data directory
  # and indexed by name and by fingering on first use, which makes the same
  # two lookups constant-time without a thread pool.
  class Database
    Chord = Struct.new(:name, :positions)

    MUTED = "x"

    def initialize(path: nil)
      @path = path || self.class.default_path
    end

    def self.default_path = File.join(Fretboard.data_dir, "chords.txt")

    def chords = @chords ||= parse(File.read(@path))

    # The database entry for a serialized chord name, or nil.
    def chord_from_name(name) = by_name[name.downcase]

    # The name of the first chord in the set that has this fingering, or nil.
    def name_from_chord(query_chord) = by_chord[query_chord]

    # Every stored fingering of a chord name, lowest first; empty when the name
    # is not in the set.
    def positions_from_name(name)
      chord_from_name(name).then do |chord|
        if chord.nil?
          []
        else
          chord.positions
        end
      end
    end

    private

      def by_name
        @by_name ||= {}.tap do |index|
          chords.each do |chord|
            index[chord.name.downcase] ||= chord
          end
        end
      end

      def by_chord
        @by_chord ||= {}.tap do |index|
          chords.each do |chord|
            chord.positions.each { |position| index[position] ||= chord.name }
          end
        end
      end

      def parse(data)
        data.split("\n\n").filter_map do |block|
          block_lines(block).then do |lines|
            if lines.empty?
              nil
            else
              Chord.new(lines.first, lines.drop(1).map { |line| position(line) })
            end
          end
        end
      end

      def block_lines(block) = block.lines.map(&:chomp).reject(&:empty?)

      def position(line)
        line.split.map do |value|
          if value == MUTED
            nil
          else
            Integer(value, 10)
          end
        end
      end
  end
end
