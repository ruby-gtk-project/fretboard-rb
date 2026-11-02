# frozen_string_literal: true

module Fretboard
  # The application id upstream uses, which is also the name of the app icon
  # and of the directory the saved chord and bookmarks are written to.
  APP_ID = "dev.bragefuglseth.Fretboard"

  # Where the chord set, the stylesheet, the icons and the diagram assets live.
  # The directory sits next to lib/ in a checkout, and is shipped in the gem.
  def self.data_dir = File.expand_path("../data", __dir__)

  def self.icons_dir = File.join(data_dir, "icons")

  def self.assets_dir = File.join(data_dir, "assets")

  def self.asset_path(name) = File.join(assets_dir, name)
end

require_relative "fretboard/application"
