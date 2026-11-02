# frozen_string_literal: true

module Fretboard
  # ChordOps holds the chord arithmetic and chord-name formatting.
  #
  # Ported from upstream's src/chord_ops.rs.
  #
  # A chord is an array of six values, one per string, low E first. A value is
  # nil for a muted string, 0 for an open string, and otherwise the number of
  # the fret pressed down. That is upstream's `[Option<usize>; 6]`.
  module ChordOps
    # Chords that are always shown in fret position 1, even though they have a
    # fingered fret higher up the neck.
    SPECIAL_CASE_CHORDS = [
      [nil, 0, 2, 2, 2, 0], # A
      [nil, 0, 2, 2, nil, 0], # A5
      [nil, 0, 2, 0, 2, 0], # A7
      [nil, 0, 2, 4, 2, 0], # Aadd9
      [nil, 0, 2, 2, 3, 0], # Asus4
      [nil, 2, 0, 2, 0, 2], # Bm7
      [nil, 3, 2, 0, 0, 0], # Cmaj7
      [nil, nil, 0, 2, 3, 2], # D
      [nil, nil, 0, 2, 3, nil], # D5
      [nil, nil, 0, 2, 0, 2], # D6
      [nil, nil, 0, 2, 2, 2], # Dmaj7
      [nil, nil, 0, 2, 3, 3], # Dsus4
      [0, 2, 2, 0, 0, 0], # Em
      [0, 2, 2, 0, 2, 0], # Em6
      [0, 2, 0, 0, 0, 0], # Em7
      [0, 2, 2, nil, 0, 2], # Esus2
      [0, 2, 2, 2, 0, 0], # Esus4
      [3, 2, 0, 0, 0, 3], # G
      [3, 2, 0, 0, 3, 3], # G alternative
      [3, 2, 0, 0, 0, 0], # G6
    ].freeze

    # The characters that turn a following "#" into a sharp sign, and a
    # following "b" into a flat sign.
    SHARPENABLE = %w[a c d f g j m 2 4 7].freeze
    FLATTENABLE = %w[a b d e g j m 2 4 7].freeze

    ENHARMONIC_EQUIVALENTS = {
      "c#" => "db",
      "d#" => "eb",
      "f#" => "gb",
      "g#" => "ab",
      "a#" => "bb",
      "db" => "c#",
      "eb" => "d#",
      "gb" => "f#",
      "ab" => "g#",
      "bb" => "a#",
    }.freeze

    module_function

    # Finds the length of the barre in an *adjusted* chord — one whose lowest
    # fingered fret has been moved to fret 1. Walks the strings from the high E
    # down, counting fret-1 notes, and stops as soon as a muted or open string
    # breaks the run.
    def find_barre_length(chord)
      chord.reverse.then do |strings|
        if strings.count(1) < 2
          0
        else
          scan_barre(strings)
        end
      end
    end

    # The fret the diagram's first row represents: the lowest fingered fret,
    # except for the special-case chords, which always sit at fret 1. nil when
    # nothing is fingered at all.
    def lowest_fingered_fret(chord)
      if SPECIAL_CASE_CHORDS.include?(chord)
        1
      else
        chord.compact.select(&:positive?).min
      end
    end

    # Moves a chord's fingered frets so they are relative to `barre`, the fret
    # the diagram starts at. Open and muted strings are left alone.
    def adjust_chord(chord, barre)
      offset(barre).then do |amount|
        chord.map do |value|
          adjust_value(value, amount)
        end
      end
    end

    # Turns typed input ("c#m7") into the name as it is displayed ("C♯m7"):
    # whitespace stripped, "#" and "b" after a note or a quality turned into
    # the real sharp and flat signs, the first letter and anything after a
    # slash capitalised, and the three word-like qualities spaced out.
    def prettify_chord_name(input)
      [" ", *input.each_char.reject { |char| char.match?(/\s/) }]
        .map { |char| char.downcase }
        .each_cons(2)
        .map { |previous, char| prettify_char(previous, char) }
        .join
        .gsub("dim", " dim")
        .gsub("aug", " aug")
        .gsub("maj", " maj")
    end

    # The inverse of prettify_chord_name, for database lookups and storage:
    # no whitespace, ASCII "#" and "b", all lowercase.
    def serialize_chord_name(input)
      input
        .each_char
        .reject { |char| char.match?(/\s/) }
        .join
        .gsub("♯", "#")
        .gsub("♭", "b")
        .downcase
    end

    # The other spelling of a chord's root note, if it has one: "c#" for "db".
    # The name must already be serialized.
    def enharmonic_equivalent(chord_name)
      ENHARMONIC_EQUIVALENTS[chord_name[0, 2]]
    end

    def scan_barre(strings)
      barre_length = 0
      note_count = 0

      strings.each_with_index do |value, index|
        if value == 1
          barre_length = index + 1
          note_count += 1
        end

        # An out-of-range index reads as nil, the same as a muted string, which
        # is harmless: both end the walk, and so does running out of strings.
        if run_broken?(value, strings[index + 1])
          break
        end
      end

      if note_count > 1
        barre_length
      else
        0
      end
    end

    def run_broken?(value, following)
      [value, following].any? { |string| string.nil? || string.zero? }
    end

    def offset(barre)
      if barre.zero?
        0
      else
        barre - 1
      end
    end

    def adjust_value(value, amount)
      if value.nil? || value.zero?
        value
      else
        value - amount
      end
    end

    def prettify_char(previous, char)
      if char == "#" && SHARPENABLE.include?(previous)
        "♯"
      elsif char == "b" && FLATTENABLE.include?(previous)
        "♭"
      elsif [" ", "/"].include?(previous)
        char.upcase
      else
        char
      end
    end
  end
end
