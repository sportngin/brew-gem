require 'erb'
require 'tempfile'

module Brew::Gem::CLI
  module_function

  COMMANDS = {
    "install"   => ("Install a brew gem, accepts an optional version argument\n" +
                    "            (e.g. brew gem install <name> [version])"),
    "upgrade"   => "Upgrade to the latest version of a brew gem",
    "uninstall" => "Uninstall a brew gem",
    "info"      => "Show information for an installed gem",
    "help"      => "This message"
  }

  def help_msg
    (["Please specify a gem name (e.g. brew gem command <name>)"] +
      COMMANDS.map {|name, desc| "  #{name} - #{desc}"}).join("\n")
  end

  def fetch_version(name, version = nil)
    gems = `gem list --remote "^#{name}$"`.lines

    unless gems.detect { |f| f =~ /^#{name} \(([^\s,]+).*\)/ }
      abort "Could not find a valid gem '#{name}'"
    end

    version ||= $1
    version
  end

  def process_args(args)
    abort help_msg unless args[0]
    abort "unknown command: #{args[0]}\n#{help_msg}" unless COMMANDS.keys.include?(args[0])

    if args[0] == 'help'
      STDERR.puts help_msg
      exit 0
    end

    args[0..3]
  end

  def expand_formula(name, version, use_homebrew_ruby=false)
    klass           = 'Gem' + name.capitalize.gsub(/[-_.\s]([a-zA-Z0-9])/) { $1.upcase }.gsub('+', 'x')
    user_gemrc      = "#{ENV['HOME']}/.gemrc"
    homebrew_prefix = ENV['HOMEBREW_PREFIX'] || `brew --prefix`.chomp
    template_file   = File.expand_path('../formula.rb.erb', __FILE__)
    template        = ERB.new(File.read(template_file))
    template.result(binding)
  end

  def with_temp_formula(name, version, use_homebrew_ruby)
    filename = File.join Dir.tmpdir, "gem-#{name}.rb"

    open(filename, 'w') do |f|
      f.puts expand_formula(name, version, use_homebrew_ruby)
    end

    yield filename
  ensure
    File.unlink filename
  end

  def run(args = ARGV)
    command, name, supplied_version, homebrew_ruby = process_args(args)
    homebrew_ruby_flag = "--homebrew-ruby"
    if supplied_version == homebrew_ruby_flag
      supplied_version = nil
      homebrew_ruby = homebrew_ruby_flag
    end

    use_homebrew_ruby = homebrew_ruby == homebrew_ruby_flag

    version = fetch_version(name, supplied_version)

    if command == "uninstall"
      command = "uninstall --ignore-dependencies"
    end

    with_temp_formula(name, version, use_homebrew_ruby) do |filename|
      system "brew #{command} #{filename}"
      exit $?.exitstatus unless $?.success?
    end
  end
end
