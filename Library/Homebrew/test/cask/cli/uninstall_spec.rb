describe Hbc::CLI::Uninstall, :cask do
  it "shows an error when a bad Cask is provided" do
    expect {
      Hbc::CLI::Uninstall.run("notacask")
    }.to raise_error(Hbc::CaskUnavailableError)
  end

  it "shows an error when a Cask is provided that's not installed" do
    expect {
      Hbc::CLI::Uninstall.run("local-caffeine")
    }.to raise_error(Hbc::CaskNotInstalledError)
  end

  it "tries anyway on a non-present Cask when --force is given" do
    expect {
      Hbc::CLI::Uninstall.run("local-caffeine", "--force")
    }.not_to raise_error
  end

  it "can uninstall and unlink multiple Casks at once" do
    caffeine = Hbc::CaskLoader.load_from_file(TEST_FIXTURE_DIR/"cask/Casks/local-caffeine.rb")
    transmission = Hbc::CaskLoader.load_from_file(TEST_FIXTURE_DIR/"cask/Casks/local-transmission.rb")

    shutup do
      Hbc::Installer.new(caffeine).install
      Hbc::Installer.new(transmission).install
    end

    expect(caffeine).to be_installed
    expect(transmission).to be_installed

    shutup do
      Hbc::CLI::Uninstall.run("local-caffeine", "local-transmission")
    end

    expect(caffeine).not_to be_installed
    expect(Hbc.appdir.join("Transmission.app")).not_to exist
    expect(transmission).not_to be_installed
    expect(Hbc.appdir.join("Caffeine.app")).not_to exist
  end

  it "calls `uninstall` before removing artifacts" do
    cask = Hbc::CaskLoader.load_from_file(TEST_FIXTURE_DIR/"cask/Casks/with-uninstall-script-app.rb")

    shutup do
      Hbc::Installer.new(cask).install
    end

    expect(cask).to be_installed
    expect(Hbc.appdir.join("MyFancyApp.app")).to exist

    expect {
      shutup do
        Hbc::CLI::Uninstall.run("with-uninstall-script-app")
      end
    }.not_to raise_error

    expect(cask).not_to be_installed
    expect(Hbc.appdir.join("MyFancyApp.app")).not_to exist
  end

  it "can uninstall Casks when the uninstall script is missing, but only when using `--force`" do
    cask = Hbc::CaskLoader.load_from_file(TEST_FIXTURE_DIR/"cask/Casks/with-uninstall-script-app.rb")

    shutup do
      Hbc::Installer.new(cask).install
    end

    expect(cask).to be_installed

    Hbc.appdir.join("MyFancyApp.app").rmtree

    expect {
      shutup do
        Hbc::CLI::Uninstall.run("with-uninstall-script-app")
      end
    }.to raise_error(Hbc::CaskError, /does not exist/)

    expect(cask).to be_installed

    expect {
      shutup do
        Hbc::CLI::Uninstall.run("with-uninstall-script-app", "--force")
      end
    }.not_to raise_error

    expect(cask).not_to be_installed
  end

  describe "when multiple versions of a cask are installed" do
    let(:token) { "versioned-cask" }
    let(:first_installed_version) { "1.2.3" }
    let(:last_installed_version) { "4.5.6" }
    let(:timestamped_versions) {
      [
        [first_installed_version, "123000"],
        [last_installed_version,  "456000"],
      ]
    }
    let(:caskroom_path) { Hbc.caskroom.join(token).tap(&:mkpath) }

    before(:each) do
      timestamped_versions.each do |timestamped_version|
        caskroom_path.join(".metadata", *timestamped_version, "Casks").tap(&:mkpath)
                     .join("#{token}.rb").open("w") do |caskfile|
                       caskfile.puts <<-EOS.undent
                         cask '#{token}' do
                           version '#{timestamped_version[0]}'
                         end
                       EOS
                     end
        caskroom_path.join(timestamped_version[0]).mkpath
      end
    end

    it "uninstalls one version at a time" do
      shutup do
        Hbc::CLI::Uninstall.run("versioned-cask")
      end

      expect(caskroom_path.join(first_installed_version)).to exist
      expect(caskroom_path.join(last_installed_version)).not_to exist
      expect(caskroom_path).to exist

      shutup do
        Hbc::CLI::Uninstall.run("versioned-cask")
      end

      expect(caskroom_path.join(first_installed_version)).not_to exist
      expect(caskroom_path).not_to exist
    end

    it "displays a message when versions remain installed" do
      expect {
        expect {
          Hbc::CLI::Uninstall.run("versioned-cask")
        }.not_to output.to_stderr
      }.to output(/#{token} #{first_installed_version} is still installed./).to_stdout
    end
  end

  describe "when Casks in Taps have been renamed or removed" do
    let(:app) { Hbc.appdir.join("ive-been-renamed.app") }
    let(:caskroom_path) { Hbc.caskroom.join("ive-been-renamed").tap(&:mkpath) }
    let(:saved_caskfile) { caskroom_path.join(".metadata", "latest", "timestamp", "Casks").join("ive-been-renamed.rb") }

    before do
      app.tap(&:mkpath)
         .join("Contents").tap(&:mkpath)
         .join("Info.plist").tap(&FileUtils.method(:touch))

      caskroom_path.mkpath

      saved_caskfile.dirname.mkpath

      IO.write saved_caskfile, <<-EOS.undent
        cask 'ive-been-renamed' do
          version :latest

          app 'ive-been-renamed.app'
        end
      EOS
    end

    it "can still uninstall those Casks" do
      shutup do
        Hbc::CLI::Uninstall.run("ive-been-renamed")
      end

      expect(app).not_to exist
      expect(caskroom_path).not_to exist
    end
  end

  describe "when no Cask is specified" do
    it "raises an exception" do
      expect {
        Hbc::CLI::Uninstall.run
      }.to raise_error(Hbc::CaskUnspecifiedError)
    end
  end

  describe "when no Cask is specified, but an invalid option" do
    it "raises an exception" do
      expect {
        Hbc::CLI::Uninstall.run("--notavalidoption")
      }.to raise_error(Hbc::CaskUnspecifiedError)
    end
  end
end
