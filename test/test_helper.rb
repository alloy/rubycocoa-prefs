$: << "/Users/eloy/code/MacRuby/rucola/lib"

require 'rubygems' rescue LoadError
require 'rucola/test_spec'
require 'mocha'

framework 'Cocoa'


# Without this helper we get segfaults, probably because the objects stored
# in the defaults are not really being maintained during the tests.
require 'singleton'
class UserPreferences
  include Singleton
  
  def initialize
    reset!
  end
  
  def registerDefaults(defaults)
    @defaults = defaults
  end
  
  def [](key)
    @defaults.merge(@preferences)[key]
  end
  alias_method :objectForKey, :[]
  
  def []=(key, value)
    @preferences[key] = value
  end
  alias_method :setObjectForKey, :[]=
  
  def synchronize
  end
  
  def reset!
    @preferences = {}
    @defaults = {}
  end
end

# We don't want test ruining our preferences
class NSUserDefaults < NSObject
  def self.standardUserDefaults
    UserPreferences.instance
  end
end