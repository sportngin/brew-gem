require 'spec_helper'

RSpec.describe Brew::Gem::CLI do
  before { ENV['HOMEBREW_PREFIX'] = '/usr/local' }
  let(:cli) { described_class }

  context "Arguments" do
    let(:args) { ['install', 'gli', '1.0', '--homebrew-ruby', '--force', '--', '--with-cflags=-Wall'] }
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

    it 'parses the brew arguments' do
      expect(subject.to_brew_args).to eq(['install', '--force'])
    end

    it 'parses the gem arguments' do
      expect(subject.to_gem_args).to eq(['--', '--with-cflags=-Wall'])
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
      allow(cli).to receive(:write_formula).and_return(formula)
      allow(cli).to receive(:fetch_version) {|n,v| v || version }
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
        expect(cli).to have_received(:write_formula).with(gem, version, true, [])
      end
    end

    context 'with a homebrew ruby not installed' do
      let(:opt_ruby_exists) { false }

      it 'installs with system ruby by default' do
        cli.run ['install', gem]
        expect(cli).to have_received(:write_formula).with(gem, version, false, [])
      end
    end

    it 'accepts an optional requested version' do
      cli.run ['install', gem, '2.2.2']
      expect(command.split).to eql(['brew', 'install', '--formula', formula])
      expect(cli).to have_received(:write_formula).with(gem, '2.2.2', true, [])
    end

    it 'accepts a --homebrew-ruby flag' do
      cli.run ['install', gem, '--homebrew-ruby']
      expect(command.split).to eql(['brew', 'install', '--formula', formula])
      expect(cli).to have_received(:write_formula).with(gem, version, true, [])
    end

    it 'accepts a --homebrew-ruby flag anywhere' do
      cli.run ['install', '--homebrew-ruby', gem]
      expect(command.split).to eql(['brew', 'install', '--formula', formula])
      expect(cli).to have_received(:write_formula).with(gem, version, true, [])
    end

    it 'accepts a --system-ruby flag' do
      cli.run ['install', gem, '--system-ruby']
      expect(command.split).to eql(['brew', 'install', '--formula', formula])
      expect(cli).to have_received(:write_formula).with(gem, version, false, [])
    end

    it 'accepts other flags and keeps the order' do
      cli.run ['-v', 'uninstall', '--force', gem, '2.1.2']
      expect(command.split).to eql(['brew', '-v', 'uninstall', '--force', '--formula', formula])
      expect(cli).to have_received(:write_formula).with(gem, '2.1.2', true, [])
    end

    it 'accepts flags for gem install and keeps the order' do
      cli.run ['-v', 'uninstall', '--force', gem, '2.1.2', '--', '--with-cflags=-Wall']
      expect(command.split).to eql(['brew', '-v', 'uninstall', '--force', '--formula', formula])
      expect(cli).to have_received(:write_formula).with(gem, '2.1.2', true, ['--', '--with-cflags=-Wall'])
    end
  end
end
