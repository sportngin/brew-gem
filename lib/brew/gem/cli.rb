require 'erb'
require 'tempfile'
require 'fileutils'
require 'optparse'
require 'shellwords'

module Brew::Gem::CLI
  module_function

  COMMANDS = {
    "install"   => ("Install a brew gem, accepts an optional version argument\n" +
                    "            (e.g. brew gem install <name> [version])"),
    "upgrade"   => "Upgrade to the latest version of a brew gem",
    "uninstall" => "Uninstall a brew gem",
    "info"      => "Show information for an installed gem",
    "formula"   => "Print out the generated formula for a gem",
    "help"      => "This message"
  }

  HOMEBREW_RUBY_FLAG = "--homebrew-ruby"
  SYSTEM_RUBY_FLAG   = "--system-ruby"
  RUBY_FLAGS = [HOMEBREW_RUBY_FLAG, SYSTEM_RUBY_FLAG]

  class Arguments
    attr_reader :ruby_flag, :command, :gem, :supplied_version,
      :brew_flags, :gem_flags, :install_flags

    def initialize(args)
      parse(args)
    end

    def parse(args)
      @brew_flags = []
      @gem_flags = []
      @install_flags = []
      option_args = args.dup

      separator_index = option_args.index('--')
      if separator_index
        @install_flags = option_args[separator_index..-1]
        option_args = option_args[0...separator_index]
      end

      OptionParser.new do |parser|
        parser.on(HOMEBREW_RUBY_FLAG, 'Use Homebrew Ruby') do
          @ruby_flag = HOMEBREW_RUBY_FLAG
        end
        parser.on(SYSTEM_RUBY_FLAG, 'Use system Ruby') do
          @ruby_flag = SYSTEM_RUBY_FLAG
        end

        parser.on('-d', '--debug', 'Pass debug mode to brew') do
          @brew_flags << '--debug'
          @gem_flags << '--debug'
        end
        parser.on('--display-times', 'Print brew install times') do
          @brew_flags << '--display-times'
        end
        parser.on('-f', '--force', 'Force') do |f|
          @brew_flags << '--force' if f
        end
        parser.on('-v', '--verbose', 'Print verbose brew output') do
          @brew_flags << '--verbose'
          @gem_flags << '--verbose'
        end
        parser.on('-n', '--dry-run', 'Show what brew would do') do
          @brew_flags << '--dry-run'
        end
        parser.on('--ask', 'Ask brew for confirmation') do
          @brew_flags << '--ask'
        end
        parser.on('--ignore-dependencies', 'Skip brew dependencies') do
          @brew_flags << '--ignore-dependencies'
        end
        parser.on('--only-dependencies', 'Install only brew dependencies') do
          @brew_flags << '--only-dependencies'
        end
        parser.on('--cc COMPILER', 'Compile with the specified compiler') do |compiler|
          @brew_flags += ['--cc', compiler]
        end
        parser.on('-s', '--build-from-source', 'Build the formula from source') do
          @brew_flags << '--build-from-source'
        end
        parser.on('--force-bottle', 'Force brew to install from a bottle') do
          @brew_flags << '--force-bottle'
        end
        parser.on('--include-test', 'Install brew test dependencies') do
          @brew_flags << '--include-test'
        end
        parser.on('--HEAD', 'Install the formula HEAD version') do
          @brew_flags << '--HEAD'
        end
        parser.on('--fetch-HEAD', 'Fetch upstream HEAD for outdated checks') do
          @brew_flags << '--fetch-HEAD'
        end
        parser.on('--keep-tmp', 'Keep temporary brew files') do
          @brew_flags << '--keep-tmp'
        end
        parser.on('--debug-symbols', 'Generate debug symbols') do
          @brew_flags << '--debug-symbols'
        end
        parser.on('--build-bottle', 'Prepare the formula for bottling') do
          @brew_flags << '--build-bottle'
        end
        parser.on('--skip-post-install', 'Skip brew post-install steps') do
          @brew_flags << '--skip-post-install'
        end
        parser.on('--skip-link', 'Skip linking the keg') do
          @brew_flags << '--skip-link'
        end
        parser.on('--as-dependency', 'Mark as installed as a dependency') do
          @brew_flags << '--as-dependency'
        end
        parser.on('--bottle-arch ARCH', 'Build bottles for the specified architecture') do |arch|
          @brew_flags += ['--bottle-arch', arch]
        end
        parser.on('-i', '--interactive', 'Open an interactive brew build shell') do
          @brew_flags << '--interactive'
        end
        parser.on('-g', 'Pass brew -g through to the selected command') do
          @brew_flags << '-g'
        end
        parser.on('--git', 'Create a Git repository while brewing') do
          @brew_flags << '--git'
        end
        parser.on('--overwrite', 'Overwrite existing files while linking') do
          @brew_flags << '--overwrite'
        end
        parser.on('--minimum-version VERSION', '--min-version VERSION', 'Only upgrade below a minimum version') do |version|
          @brew_flags += ['--minimum-version', version]
        end
        parser.on('-q', '--quiet', 'Make brew output quieter') do
          @brew_flags << '--quiet'
          @gem_flags << '--quiet'
        end
        parser.on('-b', '--both', 'Both') do |f|
          @gem_flags << '--both' if f
        end
        parser.on('-l', '--local', 'Local') do |f|
          @gem_flags << '--local' if f
        end
        parser.on('-r', '--remote', 'Remote') do |f|
          @gem_flags << '--remote' if f
        end
        parser.on('--clear-sources', 'Clear sources') do |f|
          @gem_flags << '--clear-sources' if f
        end
        parser.on('--prerelease', 'Prerelease') do |f|
          @gem_flags << '--prerelease' if f
        end
        parser.on('--no-prerelease', 'No Prerelease') do |f|
          @gem_flags << '--no-prerelease' if f
        end
        parser.on('--platform URL', 'Specify platform') do |src|
          @gem_flags += ['--platform', src]
        end
        parser.on('--source URL', 'Specify gem source') do |src|
          @gem_flags += ['--source', src]
        end
      end.parse!(option_args)
      @command = option_args[0]
      @gem = option_args[1]
      @supplied_version = option_args[2]
    end

    def flags
      to_brew_args + to_gem_args
    end

    def to_gem_args
      gem_flags + install_flags
    end

    def to_brew_args
      [command, *brew_flags].compact
    end
  end

  def help_msg
    (["Please specify a gem name (e.g. brew gem command <name>)"] +
      COMMANDS.map {|name, desc| "  #{name} - #{desc}"}).join("\n")
  end

  def fetch_version(name, arguments)
    version = arguments.supplied_version
    gems = `gem list --remote #{arguments.gem_flags.shelljoin} "^#{name}$"`.lines

    unless gems.detect { |f| f =~ /^#{name} \(([^\s,]+).*\)/ }
      abort "Could not find a valid gem '#{name}'"
    end

    version ||= $1
    version
  end

  def process_args(args)
    arguments = Arguments.new(args)
    command   = arguments.command
    abort help_msg unless command
    abort "unknown command: #{command}\n#{help_msg}" unless COMMANDS.keys.include?(command)

    if command == 'help'
      STDERR.puts help_msg
      exit 0
    end

    arguments
  end

  def homebrew_prefix
    @homebrew_prefix ||= ENV['HOMEBREW_PREFIX'] || `brew --prefix`.chomp
  end

  def gemrc_path
    # Support XDG config directory (Ruby >= 4.0 uses ~/.config/gem/gemrc)
    xdg_gemrc = File.join(ENV.fetch("XDG_CONFIG_HOME", "#{ENV['HOME']}/.config"), "gem", "gemrc")
    legacy_gemrc = "#{ENV['HOME']}/.gemrc"
    if File.exist?(xdg_gemrc)
      xdg_gemrc
    else
      legacy_gemrc
    end
  end

  def homebrew_tap
    @homebrew_tap ||=  File.join(`brew --repository`.chomp, 'Library/Taps/brew-gem/homebrew-gems')
  end

  def expand_formula(name, version, use_homebrew_ruby = false, gem_flags = [], install_flags = [])
    klass           = 'Gem' + name.capitalize.gsub(/[-_.\s]([a-zA-Z0-9])/) { $1.upcase }.gsub('+', 'x')
    user_gemrc      = gemrc_path
    template_file   = File.expand_path('../formula.rb.erb', __FILE__)
    template        = ERB.new(File.read(template_file))
    template.result(binding)
  end

  def write_formula(name, version, use_homebrew_ruby, gem_flags, install_flags)
    gem_name = "gem-#{name}"
    filename = File.join homebrew_tap, "#{gem_name}.rb"

    FileUtils.mkdir_p homebrew_tap
    open(filename, 'w') do |f|
      f.puts expand_formula(name, version, use_homebrew_ruby, gem_flags, install_flags)
    end

    [filename, "brew-gem/gems/#{gem_name}"]
  end

  def homebrew_ruby?(ruby_flag)
    File.exist?("#{homebrew_prefix}/opt/ruby") &&
      ruby_flag.nil? || ruby_flag == HOMEBREW_RUBY_FLAG
  end

  def run(args = ARGV)
    arguments = process_args(args)
    name      = arguments.gem
    version   = fetch_version(name, arguments)
    filename, formula = write_formula(name, version, homebrew_ruby?(arguments.ruby_flag), arguments.gem_flags, arguments.install_flags)
    case arguments.command
    when "formula"
      $stdout.puts File.read(filename)
    else
      system "brew #{(arguments.to_brew_args + ['--formula', formula]).shelljoin}"
      exit $?.exitstatus unless $?.success?
    end
  end
end
