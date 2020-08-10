require 'bundler/inline'
require 'net/http'
require 'open3'
require 'uri'
require 'yaml'

gemfile do
  source 'https://rubygems.org'
  gem 'down'
  gem 'nokogiri'
end

class CLI
  def self.execute(*cmd)
    puts "▶️   #{cmd.join(' ')}"
    output, status = Open3.capture2e(*[cmd].flatten)
    puts output.split("\n").map.with_index { |line, index| "#{index.zero? ? '◀️' : ' '}   #{line}" }
    [output, status]
  end

  def self.execute?(*cmd)
    puts "▶️ ❓#{cmd.join(' ')}"
    _output, status = execute(*cmd)
    status.to_i.zero?
  end

  def self.execute!(*cmd)
    puts "▶️ ❗ #{cmd.join(' ')}"
    output, status = execute(*cmd)

    if status.to_i.zero?
      output
    else
      raise "Command failed!\n  ▶️#{cmd.join(' ')}\n  #{output}"
    end
  end
end

class Installer
  def self.download_and_install_app(url)
    temp_file = Down.download(url)
    extension = File.extname(temp_file.original_filename)[1..-1].downcase
    file_name = File.basename(temp_file.original_filename)

    case extension
    when 'dmg' then install_dmg_file(temp_file)
    when 'app' then install_app_file(temp_file)
    else raise("Don't know how to install #{file_name}, downloaded to #{temp_file.path}")
    end
  end

  private

  def self.install_app_file(temp_file)
    CLI.execute!('sudo', 'mv', temp_file.path, '/Applications/')
  end

  def self.install_dmg_file(temp_file)
    basename = File.basename(temp_file.original_filename, '.*')

    CLI.execute!(<<~CMD)
      hdiutil mount #{temp_file.path}
      sudo mv /Volumes/#{basename}/#{basename}.app /Applications
      hdiutil unmount /Volumes/#{basename}
    CMD
  end
end

class Web
  def self.read(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    response = http.get(uri.request_uri)

    unless (200..300).cover?(response.code.to_i)
      raise "Unexpected response for #{url}: #{response}"
    end

    response.body
  end

  def self.find(url, xpath)
    html = read(url)
    document = Nokogiri::HTML(html)
    document.at_xpath(xpath.strip) || raise("Could not find XPath #{xpath} in document #{url}")
  end
end

namespace :xcode_cli do
  task :install do
    CLI.execute!('xcode-select --install')
  end

  task :default do
    Rake::Task['xcode_cli:install'].invoke unless CLI.execute?('xcode-select -p')
  end
end

task xcode_cli: 'xcode_cli:default'

namespace :brew do
  namespace :core do
    task install: :xcode_cli do
      CLI.execute!(<<~CMD)
        /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  
        # Install ZSH completions
        if type brew &>/dev/null; then
          FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH
      
          autoload -Uz compinit
          compinit
        fi
      CMD
    end

    task :default do
      Rake::Task['brew:core:install'].invoke unless CLI.execute?('type brew')
    end
  end

  task core: 'core:default'

  namespace :package do
    task :install, [:package_name] => 'brew:core' do |_task, args|
      CLI.execute!('brew', 'install', args.package_name)
    end

    task :ensure_installed, [:package_name] do |_task, args|
      output, status = CLI.execute('brew list -1')
      package_installed = status.to_i.zero? && output.split("\n").include?(args.package_name)

      Rake::Task['brew:package:install'].invoke(args.package_name) unless package_installed
    end
  end

  task :package, [:package_name] do |_task, args|
    Rake::Task['brew:package:ensure_installed'].invoke(args.package_name)
  end

  namespace :cask_package do
    task :install, [:package_name] => 'brew:core' do |_task, args|
      CLI.execute!('brew', 'cask', 'install', args.package_name)
    end

    task :ensure_installed, [:package_name] do |_task, args|
      output, status = CLI.execute('brew cask list -1')
      package_installed = status.to_i.zero? && output.split("\n").include?(args.package_name)

      Rake::Task['brew:cask_package:install'].invoke(args.package_name) unless package_installed
    end
  end

  task :cask_package, [:package_name] do |_task, args|
    Rake::Task['brew:cask_package:ensure_installed'].invoke(args.package_name)
  end
end

namespace :asdf do
  namespace :core do
    task :install do
      %w[
        coreutils automake autoconf openssl libyaml readline libxslt libtool unixodbc unzip curl asdf
      ].each do |package_name|
        Rake::Task['brew:package'].invoke(package_name)
      end
    end

    task :ensure_installed do
      Rake::Task['asdf:core:install'].invoke unless CLI.execute?('type asdf')
    end
  end

  task core: 'core:ensure_installed'

  namespace :plugin do
    task :ensure_installed, [:plugin_name] do |_task, args|
      output, status = CLI.execute('asdf plugin-list')
      plugin_installed = status.to_i.zero? && output.split("\n").include?(args.plugin_name)

      Rake::Task["asdf:#{args.plugin_name}:install"].invoke unless plugin_installed
    end
  end

  task :plugin, [:plugin_name] do |_task, args|
    Rake::Task['plugin:ensure_installed'].invoke(args.plugin_name)
  end

  namespace :latest do
    task :install, [:package_name] do |_task, args|
      Rake::Task["asdf:plugin:#{args.package_name}"].invoke

      latest_version = CLI.execute!('asdf', 'latest', args.plugin_name).strip
      CLI.execute!('asdf', 'install', args.plugin_name, latest_version)
      CLI.execute!('asdf', 'global', args.plugin_name, latest_version)
    end

    task :ensure_installed, [:plugin_name] do |_task, args|
      version_output, version_status = CLI.execute('asdf', 'latest', args.plugin_name)

      latest_installed =
        if version_status.to_i.zero?
          version = version_output.strip
          output, list_status = CLI.execute('asdf', 'list', args.plugin_name)
          list_status.to_i.zero? && output.split("\n").map(&:strip).include?(version)
        else
          false
        end

      Rake::Task['asdf:latest:install'].invoke(args.plugin_name) unless latest_installed
    end
  end

  task :latest, [:plugin_name] do |_task, args|
    Rake::Task['asdf:latest:ensure_installed'].invoke(args.plugin_name)
  end

  namespace :version do
    task :install, [:plugin_name, :version] do |_task, args|
      Rake::Task["asdf:plugin:#{args.package_name}"].invoke

      CLI.execute!('asdf', 'install', args.plugin_name, args.version)
      CLI.execute!('asdf', 'global', args.plugin_name, args.version)
    end

    task :ensure_installed, [:plugin_name, :version] do |_task, args|
      output, status = CLI.execute('asdf', 'list', args.plugin_name)
      version_installed = status.to_i.zero? && output.split("\n").map(&:strip).include?(args.version)

      Rask::Task['asdf:version:install'].invoke(args.plugin_name, args.version) unless version_installed
    end
  end

  task :version, [:plugin_name, :version] do |_task, args|
    Rake::Task['asdf:version:ensure_installed'].invoke(args.plugin_name, args.version)
  end

  namespace :ruby do
    task install: 'asdf:core' do
      %w[ruby-build openssl libyaml libffi].each do |package_name|
        Rake::Task['brew:package'].invoke(package_name)
      end

      CLI.execute!('asdf plugin-add ruby https://github.com/asdf-vm/asdf-ruby.git')
    end

    task :latest do
      Rake::Task['asdf:latest'].invoke('ruby')
    end

    task :version, [:version] do |_task, args|
      Rake::Task['asdf:version'].invoke('ruby', args.version)
    end
  end

  namespace :nodejs do
    task install: 'asdf:core' do
      %w[coreutils gpg].each do |package_name|
        Rake::Task['brew:package'].invoke(package_name)
      end

      CLI.execute!('asdf plugin-add nodejs https://github.com/asdf-vm/asdf-nodejs.git')
      CLI.execute!('bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring')
    end

    task :latest do
      Rake::Task['asdf:latest'].invoke('nodejs')
    end

    task :version, [:version] do |_task, args|
      Rake::Task['asdf:version'].invoke('nodejs', args.version)
    end
  end
end

namespace :app do
  task :install, [:app_name, :web_page, :xpath] do |_task, args|
    download_url =
      if xpath
        Web.find(args.web_page, args.xpath)
      else
        args.web_page
      end

    Installer.download_and_install_app(download_url)
  end

  task :ensure_installed, [:app_name, :web_page, :xpath] do |_task, args|
    app_installed =
      Dir.chdir('/Applications') do
        Dir['*.app'].any? { |app_file_name| app_file_name == args.app_name }
      end

    Rake::Task['app:install'].invoke(args.app_name, args.web_page, args.xpath) unless app_installed
  end
end

task :app, [:app_name, :web_page, :xpath] do |_task, args|
  Rake::Task['app:ensure_installed'].invoke(args.app_name, args.web_page, args.xpath)
end

namespace :app_store do
  namespace :core do
    task install: 'brew:core' do
      Rake::Task['brew:package'].invoke('mas')
    end

    task :ensure_installed do
      Rake::Task['app_store:core:install'].invoke unless CLI.execute?('type mas')
    end
  end

  task core: 'app_store:core:ensure_installed'

  namespace :app do
    task :install, [:app_id] => 'app_store:core' do |_task, args|
      CLI.execute!('mas', 'install', args.app_id)
    end

    task :ensure_installed, [:app_id] do |_task, args|
      output, status = CLI.execute('mas', 'list')
      app_installed = status.to_i.zero? && output.split("\n").any? { |line| line.include?("#{args.app_id} ") }

      Rake::Task['app_store:app:install'].invoke(args.app_id) unless app_installed
    end
  end

  task :app, [:app_id] do |_task, args|
    Rake::Task['app_store:app:ensure_installed'].invoke(args.app_id)
  end
end

task :install do
  Rake::Task['asdf:ruby:latest'].invoke
  Rake::Task['asdf:nodejs:latest'].invoke

  %w[
    chromedriver
    elasticsearch
    git
    hub
    imagemagick
    openssl
    postgresql
    redis
    sqlite
    telnet
    wget
    yarn
  ].each do |brew_package|
    Rake::Task['brew:package'].invoke(brew_package)
  end

  %w[
    google-chrome
    firefox
    dropbox
    google-backup-and-sync
    docker
    iterm2
    macdown
    postman
    spectacle
    alfred
    brave-browser
    rubymine
    slack
    virtualbox
    vlc
    whatsapp
    atom
  ].each do |brew_cask_package|
    Rake::Task['brew:cask_package'].invoke(brew_cask_package)
  end

  Rake::Task['app'].invoke(
    'Pulse Secure.app',
    'https://support.plymouth.edu/index.php?/Default/Knowledgebase/Article/View/623/0/' \
    'how-to-install-and-connect-to-the-pulse-secure-vpn-client/#mac',
    %{ //a[contains(text(), 'Apple') and contains(text(), 'Installer')]/@href }
  )

  Rake::Task['app'].invoke(
    'Dante Virtual Soundcard.app',
    'https://my.audinate.com/support/downloads/dante-virtual-soundcard',
    %{ //a[contains(text(), 'Dante Virtual Soundcard') and contains(text(), 'macOS')]/@href }
  )

  Rake::Task['app'].invoke(
    'GitHub Desktop.app',
    'https://desktop.github.com/',
    %{ //p[contains(., 'Download for macOS')]//a[contains(text(), 'macOS')]/@href }
  )

  Rake::Task['app'].invoke(
    'Splashtop XDisplay.app',
    'https://www.splashtop.com/wiredxdisplay',
    %{ //main//a[contains(text(), 'Download') and contains(text(), 'MAC')]/@href }
  )

  Rake::Task['app'].invoke(
    'Spitfire Audio.app',
    'https://labs.spitfireaudio.com/',
    %{ //a[contains(@href, 'download') and contains(@href, 'mac')]/@href }
  )

  [
    497799835,  # Xcode
    634159523,  # MainStage
    597790822,  # SSH Proxy
    668208984,  # GIPHY CAPTURE
    926036361,  # LastPass
    1483255076, # Lockdown
    506189836,  # Harvest
    1518425043, # Boop
  ].each do |app_id|
    Rake::Task['app_store:app'].invoke(app_id)
  end
end
