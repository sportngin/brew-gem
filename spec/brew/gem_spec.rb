require 'spec_helper'
require 'fileutils'

RSpec.describe Brew::Gem, type: :aruba  do
  def brew_gem(command); run_complete "#{brew_gem_exe} #{command}"; end
  def brew(command); run_complete "brew #{command}"; end

  subject(:aruba_cmd) { brew_gem command }

  let(:help_message) { Regexp.new Regexp.quote(Brew::Gem::CLI.help_msg.lines.first) }

  context "aruba environment" do
    it "doesn't contain any Bundler or RVM stuff" do
      cmd = run_complete "env"
      output = cmd.output
      expect(output).to_not match(/^BUNDLE_/)
      expect(output).to_not match(/^GEM_/)
      expect(output).to_not match(/^RUBY(OPT|LIB)/)
    end
  end

  context "help" do
    let(:command) { "help" }

    it { is_expected.to have_output(help_message) }

    it { is_expected.to be_successfully_executed }
  end

  context "no command" do
    let(:command) { "" }

    it { is_expected.to have_output(help_message) }

    it { is_expected.to_not be_successfully_executed }
  end

  context "unknown command" do
    let(:command) { "unknown" }

    it { is_expected.to have_output(/unknown command: #{command}/) }

    it { is_expected.to have_output(help_message) }

    it { is_expected.to_not be_successfully_executed }
  end

  install_metadata = { integration: true, exit_timeout: 30 }
  install_metadata.update announce_stderr: true, announce_stdout: true if ENV['DEBUG']

  context "install/uninstall", install_metadata do
    def gli_linked?; File.exist?("#{brew('--prefix').output.chomp}/bin/gli"); end

    fixture = :all
    fixture = :each if ENV['DEBUG'] # So that Aruba announces all the before/after commands as well

    before fixture do
      # Ensure we download gli fresh
      FileUtils.rm_f Dir["#{brew('--cache').output.chomp}/gli*.gem"]
      if gli_linked?
        @gli_pre_linked = true
        raise "gli already linked in homebrew; either unlink or re-run rspec with '--tag ~integration'"
      end
      expect(brew("gem install gli")).to be_successfully_executed
    end

    after fixture do |example|
      unless @gli_pre_linked
        expect(brew("gem uninstall gli")).to be_successfully_executed
        expect(brew("list gem-gli")).to_not  be_successfully_executed
      end
    end

    after do |example|
      if example.exception && !@gli_pre_linked
        run("brew uninstall gem-gli").stop
      end
    end

    it "installs the gem" do
      expect(brew("list gem-gli")).to be_successfully_executed
    end

    it "links executables" do
      expect(gli_linked?).to be_truthy
    end
  end
end
