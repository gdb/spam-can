require 'rubygems'
require 'yaml'

module SpamCan
  class Settings
    def self.[](*keys)
      load
      datum = @data
      keys.each { |key| datum = datum[key] }
      datum
    end

    private

    def self.load
      return if loaded?
      @data = YAML.load_file(File.join(File.dirname(__FILE__), '../settings.yaml'))
    end

    def self.loaded?
      !!@data
    end
  end
end

$:.unshift(File.join(File.dirname(__FILE__)))

require 'spam-can/db'
require 'spam-can/helpers'
