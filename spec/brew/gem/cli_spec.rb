require 'spec_helper'

RSpec.describe Brew::Gem::CLI do
  before { ENV['HOMEBREW_PREFIX'] = '/usr/local' }
  let(:cli) { described_class }

  context "Arguments" do
    let(:args) { ['install', 'gli', '1.0', '--homebrew-ruby', '--force',
                  '--source', 'https://mygemserver.com', '--', '--with-cflags=-Wall'] }
    subject { described_class::Arguments.new args }

    it 'parses the command name' do
      expect(subject.command).to eq('install')
    end

    it 'parses the gem name' do
      expect(subject.gem).to eq('gli')
    end

    it 'parses the version' do
      expect(subject.supplied_version).to eq('1.0')
    end

    it 'parses the ruby flag' do
      expect(subject.ruby_flag).to eq('--homebrew-ruby')
    end

    it 'parses the brew flags' do
      expect(subject.brew_flags).to eq(['--force'])
    end

    it 'parses the gem flags' do
      expect(subject.gem_flags).to eq(['--source', 'https://mygemserver.com'])
    end

    it 'parses the install flags' do
      expect(subject.install_flags).to eq(['--', '--with-cflags=-Wall'])
    end

    it 'parses useful brew install and upgrade flags' do
      arguments = described_class::Arguments.new [
        'upgrade', 'gli',
        '--debug', '--display-times', '--force', '--verbose', '--dry-run',
        '--ask', '--build-from-source', '--force-bottle', '--include-test',
        '--HEAD', '--fetch-HEAD', '--keep-tmp', '--debug-symbols',
        '--build-bottle', '--skip-post-install', '--skip-link', '--as-dependency',
        '--overwrite', '--minimum-version', '2.0.0', '--quiet'
      ]

      expect(arguments.brew_flags).to eq([
        '--debug', '--display-times', '--force', '--verbose', '--dry-run',
        '--ask', '--build-from-source', '--force-bottle', '--include-test',
        '--HEAD', '--fetch-HEAD', '--keep-tmp', '--debug-symbols',
        '--build-bottle', '--skip-post-install', '--skip-link', '--as-dependency',
        '--overwrite', '--minimum-version', '2.0.0', '--quiet'
      ])
    end

    it 'parses brew flags with values' do
      arguments = described_class::Arguments.new [
        'install', 'gli', '--cc', 'gcc-14', '--bottle-arch', 'arm64_ventura'
      ]

      expect(arguments.brew_flags).to eq([
        '--cc', 'gcc-14', '--bottle-arch', 'arm64_ventura'
      ])
    end

    it 'adds overlapping RubyGems common flags to gem flags' do
      arguments = described_class::Arguments.new [
        'install', 'gli', '--debug', '--verbose', '--quiet'
      ]

      expect(arguments.brew_flags).to eq(['--debug', '--verbose', '--quiet'])
      expect(arguments.gem_flags).to eq(['--debug', '--verbose', '--quiet'])
    end
  end

  context "#expand_formula" do
    subject(:formula) { cli.expand_formula("foo-bar", "1.2.3", false) }

    it "generates valid Ruby" do
      IO.popen("ruby -c -", "r+") { |f| f.puts formula }

      expect($?).to be_success
    end

    it { is_expected.to match(/class GemFooBar < Formula/) }

    it { is_expected.to match(/version "1\.2\.3"/) }
    it { is_expected.to match("USE_HOMEBREW_RUBY = false") }
    it { is_expected.to match(/"fetch", "foo-bar",\n\s+"--version", gem_version, \*GEM_FLAGS/) }

    context "homebrew-ruby" do
      subject(:formula) { cli.expand_formula("foo-bar", "1.2.3", true) }
      it { is_expected.to match("USE_HOMEBREW_RUBY = true") }
    end
  end

  context "#run" do
    let(:gem)     { 'dummygem' }
    let(:version) { '1.0.1.0' }
    let(:formula) { 'temp-formula.rb' }
    let(:command) { '' }
    let(:opt_ruby_exists) { true }

    before do
      allow(cli).to receive(:exit)
      allow(cli).to receive(:system) {|x| command << x }
      allow(cli).to receive(:write_formula).and_return([formula, formula])
      allow(cli).to receive(:fetch_version) {|n, arguments| arguments.supplied_version || version }
      allow(cli).to receive(:abort) {|msg| raise msg }
      allow(File).to receive(:exist?).with('/usr/local/opt/ruby').and_return opt_ruby_exists
    end

    it 'runs brew on a formula file' do
      cli.run ['install', gem]
      expect(command.split).to eql(['brew', 'install', '--formula', formula])
    end

    context 'with a homebrew ruby installed' do
      it 'installs with homebrew ruby by default' do
        cli.run ['install', gem]
        expect(cli).to have_received(:write_formula).with(gem, version, true, [], [])
      end
    end

    context 'with a homebrew ruby not installed' do
      let(:opt_ruby_exists) { false }

      it 'installs with system ruby by default' do
        cli.run ['install', gem]
        expect(cli).to have_received(:write_formula).with(gem, version, false, [], [])
      end
    end

    it 'accepts an optional requested version' do
      cli.run ['install', gem, '2.2.2']
      expect(command.split).to eql(['brew', 'install', '--formula', formula])
      expect(cli).to have_received(:write_formula).with(gem, '2.2.2', true, [], [])
    end

    it 'accepts a --homebrew-ruby flag' do
      cli.run ['install', gem, '--homebrew-ruby']
      expect(command.split).to eql(['brew', 'install', '--formula', formula])
      expect(cli).to have_received(:write_formula).with(gem, version, true, [], [])
    end

    it 'accepts a --homebrew-ruby flag anywhere' do
      cli.run ['install', '--homebrew-ruby', gem]
      expect(command.split).to eql(['brew', 'install', '--formula', formula])
      expect(cli).to have_received(:write_formula).with(gem, version, true, [], [])
    end

    it 'accepts a --system-ruby flag' do
      cli.run ['install', gem, '--system-ruby']
      expect(command.split).to eql(['brew', 'install', '--formula', formula])
      expect(cli).to have_received(:write_formula).with(gem, version, false, [], [])
    end

    it 'accepts other brew flags' do
      cli.run ['-v', 'uninstall', '--force', gem, '2.1.2']
      expect(command.split).to eql(['brew', 'uninstall', '--verbose', '--force', '--formula', formula])
      expect(cli).to have_received(:write_formula).with(gem, '2.1.2', true, ['--verbose'], [])
    end

    it 'accepts flags for gem install' do
      cli.run ['-v', 'uninstall', '--force', gem, '2.1.2', '--', '--with-cflags=-Wall']
      expect(command.split).to eql(['brew', 'uninstall', '--verbose', '--force', '--formula', formula])
      expect(cli).to have_received(:write_formula).with(gem, '2.1.2', true, ['--verbose'], ['--', '--with-cflags=-Wall'])
    end
  end
end
