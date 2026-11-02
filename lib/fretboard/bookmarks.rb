# frozen_string_literal: true

require "json"
require "fileutils"

module Fretboard
  # Bookmark is a chord the user saved: its serialized name and its fingering.
  #
  # Ported from the Bookmark struct in upstream's src/widgets/window.rs, and
  # written with the same JSON field names, so the files this port writes are
  # the ones upstream reads.
  class Bookmark
    attr_reader :name, :chord

    def initialize(name, chord)
      @name = name
      @chord = chord
    end

    def self.from_h(data) = new(data["name"].to_s, data["chord"])

    def to_h = {name: @name, chord: @chord}

    def ==(other) = other.is_a?(Bookmark) && other.name == @name && other.chord == @chord

    alias_method :eql?, :==

    def hash = [@name, @chord].hash
  end

  # Bookmarks is the saved-chord list and the JSON file behind it.
  #
  # Ported from the bookmark handling in upstream's src/widgets/window.rs:
  # load_bookmarks, save_bookmarks, add_bookmark and remove_bookmark, plus the
  # current-chord file that window.rs writes on close and reads on startup.
  class Bookmarks
    INITIAL_CHORD_NAME = "C"
    INITIAL_CHORD = [nil, 3, 2, 0, 1, 0].freeze

    def initialize(path: nil)
      @path = path || self.class.default_path
      @entries = read
    end

    def self.data_dir
      File.join(GLib.user_data_dir, APP_ID).tap do |dir|
        FileUtils.mkdir_p(dir)
      end
    end

    def self.default_path = File.join(data_dir, "bookmarks.json")

    def self.current_chord_path = File.join(data_dir, "current_chord.json")

    # The chord the app had open when it was last closed, or the C chord the
    # app opens with the first time it is run.
    def self.load_current_chord
      if File.exist?(current_chord_path)
        read_current_chord
      else
        Bookmark.new(INITIAL_CHORD_NAME, INITIAL_CHORD.dup)
      end
    end

    def self.save_current_chord(bookmark)
      File.write(current_chord_path, JSON.generate(bookmark.to_h))
    end

    def self.read_current_chord
      Bookmark.from_h(JSON.parse(File.read(current_chord_path)))
    rescue JSON::ParserError, TypeError
      Bookmark.new(INITIAL_CHORD_NAME, INITIAL_CHORD.dup)
    end

    def each(&) = @entries.each(&)

    def to_a = @entries.dup

    def empty? = @entries.empty?

    def include?(bookmark) = @entries.include?(bookmark)

    def add(bookmark) = @entries.push(bookmark)

    def remove(query) = @entries.reject! { |bookmark| bookmark == query }

    def save
      File.write(@path, JSON.generate(@entries.map(&:to_h)))
    end

    private

      def read
        if File.exist?(@path)
          parse(File.read(@path))
        else
          []
        end
      end

      def parse(contents)
        JSON.parse(contents).map { |data| Bookmark.from_h(data) }
      rescue JSON::ParserError, TypeError, NoMethodError => error
        warn("Error parsing #{@path}: #{error.message}")
        []
      end
  end
end
