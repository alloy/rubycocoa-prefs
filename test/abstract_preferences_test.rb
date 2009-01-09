#!/usr/bin/env macruby

require File.expand_path('../test_helper', __FILE__)
require 'abstract_preferences'

class Preferences
  class TestDefaults < Namespace
    defaults_accessor :an_option, true
    defaults_accessor :another_option, true
    string_array_defaults_accessor :a_string_array, %w{ foo bar baz }, 'TestDefaultsStringWrapper'
    defaults_accessor :an_array, %w{ foo bar baz }
  end
  
  register_default_values!
end

describe "Preferences" do
  it "should be a singleton" do
    Preferences.should.include Singleton
    Preferences.instance.should.be.instance_of Preferences
  end
  
  it "should have defined a shortcut method on Kernel" do
    preferences.should.be Preferences.instance
  end
  
  it "should have created a class for a namespace and added an accessor method for the namespace" do
    Preferences::TestDefaults.superclass.should == Preferences::Namespace
    preferences.should.respond_to :test_defaults
  end
  
  it "should synchronize changes to disk" do
    NSUserDefaults.standardUserDefaults.expects(:synchronize)
    preferences.save
  end
end

describe "Preferences::AbstractPreferencesNamespace" do
  def setup
    @prefs = Preferences::TestDefaults.instance
  end
  
  it "should know the key in the prefs based on it's section class name" do
    Preferences::TestDefaults.section_defaults_key.should == 'Preferences.TestDefaults'
  end
  
  it "should should add default values to the Preferences.default_values" do
    Preferences.default_values['Preferences.TestDefaults.an_option'].should == true
  end
  
  it "should register user defaults with ::defaults_accessor" do
    @prefs.an_option.should == true
    @prefs.an_option = false
    @prefs.an_option.should == false
  end
  
  it "should create a query method for boolean preferences" do
    @prefs.another_option = true
    assert @prefs.another_option?
    @prefs.another_option = false
    assert !@prefs.another_option?
  end
  
  it "should return an array of wrapped strings for a string_array_defaults_accessor" do
    assert @prefs.a_string_array_wrapped.all? { |x| x.is_a? TestDefaultsStringWrapper }
    @prefs.a_string_array_wrapped.map { |x| x.valueForKey('string') }.should == %w{ foo bar baz }
  end
  
  it "should have a setter method for a string_array_defaults_accessor" do
    @prefs.should.respond_to :a_string_array_wrapped=
  end
  
  it "should return the key path for the defaults_accessor" do
    Preferences::TestDefaults.defaults_accessor(:an_accessor, '').should == 'Preferences.TestDefaults.an_accessor'
  end
  
  it "should register an observer for a key path" do
    observer_mock = mock('Object that observes a preference value')
    
    shared_defaults = NSUserDefaultsController.sharedUserDefaultsController
    shared_defaults.expects('addObserver:forKeyPath:options:context:').with do |observer, key_path, options, context|
      observer == observer_mock &&
        key_path == 'values.Preferences.TestDefaults.an_option' &&
        options == NSKeyValueObservingOptionNew &&
        context.nil?
    end
    
    @prefs.observe(:an_option, observer_mock)
  end
end

describe "A Preferences::StringArrayWrapper subclass" do
  def setup
    @prefs = Preferences::TestDefaults.instance
  end
  
  def teardown
    @prefs.a_string_array = %w{ foo bar baz }
  end
  
  it "should be a subclass of Preferences::StringArrayWrapper" do
    TestDefaultsStringWrapper.superclass.should.be Preferences::StringArrayWrapper
  end
  
  it "should know it's key path" do
    TestDefaultsStringWrapper.key_path.should == 'Preferences.TestDefaults.a_string_array'
  end
  
  it "should update the string it wraps in the array at the configured key path" do
    @prefs.a_string_array_wrapped.first.string = 'new_foo'
    @prefs.a_string_array.should == %w{ new_foo bar baz }
    
    @prefs.a_string_array_wrapped.last.string = 'new_baz'
    @prefs.a_string_array.should == %w{ new_foo bar new_baz }
  end
  
  it "should add the string it wraps to the array at the configured key path if initialized without index, this happens when a NSArrayController initializes an instance" do
    wrapper = TestDefaultsStringWrapper.alloc.init
    wrapper.string = 'without index'
    @prefs.a_string_array.last.should == 'without index'
    wrapper.index.should == 3
  end
  
  it "should remove the strings the wrappers wrap from the array at the configured key path and reset the indices of the wrappers" do
    wrapped = @prefs.a_string_array_wrapped
    new_wrapped = [wrapped[1]]
    Preferences::StringArrayWrapper.destroy(TestDefaultsStringWrapper, new_wrapped)
    @prefs.a_string_array.should == %w{ bar }
    new_wrapped.first.index.should == 0
  end
end

class ClassThatExtendsWithAccessorHelpers < NSObject
  extend Preferences::AccessorHelpers
  
  defaults_string_array_kvc_accessor :a_kvc_string_array, 'Preferences::TestDefaults.instance.a_string_array'
end

describe "A class that extends with Preferences::AccessorHelpers and uses ::defualts_string_array_kvc_accessor" do
  def setup
    @instance = ClassThatExtendsWithAccessorHelpers.alloc.init
  end
  
  def teardown
    Preferences::TestDefaults.instance.a_string_array = %w{ foo bar baz }
  end
  
  it "should define a defaults kvc reader accessor" do
    @instance.valueForKey('a_kvc_string_array').map { |x| x.string }.should == %w{ foo bar baz }
  end
  
  ['@instance.a_kvc_string_array = wrappers', '@instance.setValue(wrappers, forKey: "a_kvc_string_array")'].each do |setter|
    it "should remove wrappers from the preferences which are removed from the array given to the kvc setter: #{setter}" do
      Preferences::TestDefaults.instance.a_string_array = %w{ foo bar baz bla boo }
      
      2.times do
        wrappers = Preferences::TestDefaults.instance.a_string_array_wrapped
        wrappers.delete_at(1)
        eval(setter)
      end
      
      @instance.a_kvc_string_array.map { |x| x.string }.should == %w{ foo bla boo }
    end
  end
end

class ClassThatExtendsWithAccessorHelpers < NSObject
  extend Preferences::AccessorHelpers
  
  defaults_kvc_accessor :a_kvc_array, 'preferences.test_defaults.an_array'
end

describe "A class that extends with Preferences::AccessorHelpers and uses defaults_kvc_accessor" do
  def setup
    @instance = ClassThatExtendsWithAccessorHelpers.alloc.init
  end
  
  def teardown
    Preferences::TestDefaults.instance.an_array = %w{ foo bar baz }
  end
  
  it "should define a defaults kvc reader accessor" do
    @instance.valueForKey('a_kvc_array').should == %w{ foo bar baz }
  end
  
  it "should define a defaults kvc writer accessor" do
    @instance.setValue(['bar'], forKey: 'a_kvc_array')
    @instance.a_kvc_array.should == ['bar']
  end
end

class ClassThatIncludesKVOCallbackHelper
  include Preferences::KVOCallbackHelper
end

describe "A class that includes Preferences::KVOCallbackHelper" do
  def setup
    @instance = ClassThatIncludesKVOCallbackHelper.new
  end
  
  it "should call the method inflected from the key path with the new value of the preference" do
    Preferences::TestDefaults.instance.an_option = true
    @instance.expects(:an_option_changed).with(true)
    @instance.observeValueForKeyPath('values.Preferences.TestDefaults.an_option', ofObject: nil, change: {}, context: nil)
    
    Preferences::TestDefaults.instance.an_option = false
    @instance.expects(:an_option_changed).with(false)
    @instance.observeValueForKeyPath('values.Preferences.TestDefaults.an_option', ofObject: nil, change: {}, context: nil)
  end
end