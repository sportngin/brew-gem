require 'aruba/rspec'

module BrewGemBin
  def brew_gem_exe
    File.expand_path('../../../bin/brew-gem', __FILE__)
  end
end

module CleanEnv
  OUR_BREW_GEM_HOME = File.expand_path('../../..', __FILE__)
  OUR_BREW_GEM_BIN  = "#{OUR_BREW_GEM_HOME}/bin"

  def run(*args)
    clean_env = Bundler.unbundled_env
    (ENV.keys - clean_env.keys).each {|k| delete_environment_variable k }
    # Also delete any RVM crud
    delete_environment_variable "RUBYOPT"
    delete_environment_variable "RUBYLIB"
    delete_environment_variable "GEM_PATH"
    delete_environment_variable "GEM_HOME"
    path = ENV['PATH'].split(/:/)
    # Remove .rvm/.rbenv/.bundle stuff from PATH
    path = path.reject {|x| x =~ %r{/.(rvm|rbenv)/} || x =~ %r{#{OUR_BREW_GEM_HOME}/.bundle} }
    # Ensure that `brew` finds our local `brew-gem` command by putting it first in the path
    path.unshift OUR_BREW_GEM_BIN unless path.first == OUR_BREW_GEM_BIN
    set_environment_variable "PATH", path.join(":")
    run_command(*args)
  end
end

module ArubaHelpers
  def run_complete(*args)
    cmd = run(*args)
    cmd.stop
    expect(cmd).to have_finished_in_time
    cmd
  end
end

RSpec.configure do |config|
  config.include CleanEnv
  config.include BrewGemBin
  config.include ArubaHelpers
end
