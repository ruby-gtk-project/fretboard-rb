# frozen_string_literal: true

module Fretboard
  # ChordNameAlgorithm names a chord from its intervals.
  #
  # Ported from upstream's src/chord_name_algorithm.rs. It is the fallback used
  # when a chord with a given fingering is not in the database: the notes are
  # reduced to intervals above the lowest one, and the interval set is looked
  # up in a table of chord qualities.
  module ChordNameAlgorithm
    SCALE_SIZE = 12

    # Semitones above A for the open string, low E first.
    NOTE_OFFSETS = [7, 0, 5, 10, 2, 7].freeze

    NOTE_NAMES = %w[A A# B C C# D D# E F F# G G#].freeze

    # The intervals above the root that make up each chord quality. The list
    # can be extended with more possible intervals.
    SUFFIXES = {
      [0, 4, 7]              => "",
      [0, 3, 7]              => "m",
      [0, 3, 6]              => "dim",
      [0, 7]                 => "5",
      [0, 4, 7, 11]          => "maj7",
      [0, 3, 7, 11]          => "mmaj7",
      [0, 4, 7, 10]          => "7",
      [0, 3, 7, 10]          => "m7",
      [0, 3, 6, 10]          => "m7b5",
      [0, 3, 6, 9]           => "dim7",
      [0, 2, 7]              => "sus2",
      [0, 5, 7]              => "sus4",
      [0, 4, 8]              => "aug",
      [0, 4, 8, 11]          => "augmaj11",
      [0, 4, 8, 10]          => "aug7",
      [0, 2, 4, 7, 11]       => "maj9",
      [0, 2, 3, 7, 10]       => "m9",
      [0, 2, 4, 7, 10]       => "9",
      [0, 2, 4, 5, 7, 11]    => "maj11",
      [0, 2, 3, 5, 7, 10]    => "m11",
      [0, 2, 4, 5, 7, 10]    => "11",
      [0, 2, 4, 5, 7, 9, 10] => "13",
      [0, 2, 4, 7]           => "add9",
      [0, 2, 3, 7]           => "madd9",
      [0, 4, 5, 7]           => "add11",
      [0, 3, 5, 7]           => "madd11",
      [0, 4, 7, 9]           => "add13",
      [0, 3, 7, 9]           => "madd13",
      [0, 4, 5, 7, 10]       => "7add11",
      [0, 3, 5, 7, 10]       => "m7add11",
      [0, 4, 5, 7, 11]       => "maj7add11",
      [0, 3, 5, 7, 11]       => "mmaj7add11",
      [0, 4, 7, 9, 10]       => "7add13",
      [0, 3, 7, 9, 10]       => "m7add13",
      [0, 4, 7, 9, 11]       => "maj7add13",
      [0, 3, 7, 9, 11]       => "mmaj7add13",
    }.freeze

    module_function

    # The name of a chord ("Fmaj7"), or of the same chord over a different bass
    # note ("Fmaj7/C"), or nil when the interval set is not one this table
    # knows.
    def calculate_chord_name(chord)
      notes(chord).then do |played|
        isolated_chord_name(played) || chord_name_over_bass(played)
      end
    end

    # The notes a fingering sounds, as semitones above A, low string first.
    def notes(chord)
      chord.each_with_index.filter_map do |value, string|
        value.then do |fret|
          if fret.nil?
            nil
          else
            (fret + NOTE_OFFSETS[string]) % SCALE_SIZE
          end
        end
      end
    end

    # A chord name without taking alternative bass notes into account.
    def isolated_chord_name(notes)
      notes.first.then do |root|
        if root.nil?
          nil
        else
          SUFFIXES[intervals(notes, root)].then do |suffix|
            if suffix.nil?
              nil
            else
              "#{NOTE_NAMES[root]}#{suffix}"
            end
          end
        end
      end
    end

    # The same lookup with the lowest note dropped, which gives names like
    # "Fmaj7/C" for a chord whose bass note is not its root.
    def chord_name_over_bass(notes)
      isolated_chord_name(notes.drop(1)).then do |name|
        if name.nil?
          nil
        else
          "#{name}/#{NOTE_NAMES[notes.first]}"
        end
      end
    end

    def intervals(notes, root)
      notes.uniq.map { |note| (note - root) % SCALE_SIZE }.sort
    end
  end
end
