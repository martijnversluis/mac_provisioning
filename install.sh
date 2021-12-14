#!/bin/bash
set -eo pipefail

##### GENERIC #################################################################

function mp__command_is_installed {
  command_name="$1"

  type "$command_name" >/dev/null 2>&1
}

function mp__log {
  emoji="$1"
  module_name="$2"
  log_text="$3"

  echo "$emoji [$module_name] $log_text"
}

function mp__info {
  module_name="$1"
  log_text="$2"

  mp__log "ℹ️ " "$module_name" "$log_text"
}

function mp__check {
  module_name="$1"
  log_text="$2"

  mp__log "✅" "$module_name" "$log_text"
}

function mp__check_command_installed {
  module_name="$1"
  installation_check_function_name="$2"
  installation_execution_function_name="$3"

  if $($installation_check_function_name); then
    mp__check "$module_name" "is installed"
  else
    mp__info "$module_name" "is not installed. Installing now."
    $installation_execution_function_name
  fi
}

function mp__download_auxiliary_file {
  file_name="$1"

  curl "https://raw.githubusercontent.com/martijnversluis/mac_provisioning/master/$file_name" \
       --output "$HOME/$file_name"
}

##### X-CODE ##################################################################
function mp__xcode_cli__is_installed {
  xcode-select -p 1>/dev/null
}

function mp__xcode_cli__install {
  xcode-select --install
  sudo xcodebuild -license accept
}

function mp__xcode_cli__ensure_installed {
  mp__check_command_installed "xcode CLI tools" "mp__xcode_cli__is_installed" "mp__xcode_cli__install"
}

##### BREW ####################################################################
function mp__brew__install {
  mp__xcode_cli__ensure_installed
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
  eval "$(/opt/homebrew/bin/brew shellenv)"

  # Install ZSH completions
  if type brew &>/dev/null; then
    FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH

    autoload -Uz compinit || true
    compinit || true
  fi
}

function mp__brew__is_installed {
  mp__command_is_installed "brew"
}

function mp__brew__ensure_installed {
  mp__check_command_installed "brew" "mp__brew__is_installed" "mp__brew__install"
}

function mp__brew__package_is_installed {
  plugin_name="$1"

  brew list -1 | grep "$plugin_name" 1>/dev/null
}

function mp__brew__ensure_package_installed {
  plugin_names="$@"

  mp__brew__ensure_installed

  for name in $plugin_names
  do
    if mp__brew__package_is_installed $name; then
      mp__check "brew $name" "is installed"
    else
      mp__info "brew $name" "is not installed. Installing now."
      brew install $name
    fi
  done
}

function mp__brew__ensure_package_installed_from_tap {
  package_name="$1"
  tap_name="$2"

  mp__brew__ensure_installed

  if mp__brew__package_is_installed $package_name; then
    mp__check "brew $package_name" "is installed"
  else
    mp__info "brew $package_name" "is not installed. Installing now."
    brew tap "$tap_name"
    brew install "$package_name"
  fi
}

function mp__brew__service_is_running {
  service_name="$1"

  brew services list | grep "$service_name" | grep started 1>/dev/null
}

function mp__brew__ensure_service_running {
  service_names="$@"

  for name in $service_names
  do
    if mp__brew__service_is_running $name; then
      mp__check "brew $name" "is running"
    else
      mp__info "brew $name" "is not running. Starting now."
      brew services start $name
    fi
  done
}

function mp__brew__cask_package_is_installed {
  package_name="$1"

  brew cask list -1 | grep "$package_name" 1>/dev/null
}

function mp__brew__ensure_cask_package_installed {
  package_names="$@"

  mp__brew__ensure_installed

  for name in $package_names
  do
    if mp__brew__cask_package_is_installed $name; then
      mp__check "brew cask $name" "is installed"
    else
      mp__info "brew cask $name" "is not installed. Installing now."
      brew cask install $name
    fi
  done
}

##### ASDF ####################################################################

function mp__asdf_install {
  mp__brew__ensure_package_installed coreutils \
                                     automake \
                                     autoconf \
                                     openssl \
                                     libyaml \
                                     readline \
                                     libxslt \
                                     libtool \
                                     unixodbc \
                                     unzip \
                                     curl

  git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.8.1
  echo ". $HOME/.asdf/asdf.sh" >> ~/.zshrc
  . $HOME/.asdf/asdf.sh
}

function mp__asdf_is_installed {
  mp__command_is_installed "asdf"
}

function mp__asdf_ensure_installed {
  mp__check_command_installed "asdf" "mp__asdf_is_installed" "mp__asdf_install"
}

# arg 1 - plugin name
function mp__asdf_plugin_is_installed {
  asdf plugin list | grep "$1" 1>/dev/null
}

function mp__asdf__plugin_ensure_installed {
  plugin_name="$1"
  installation_function_name="$2"

  mp__asdf_ensure_installed

  if $(mp__asdf_plugin_is_installed "$plugin_name"); then
    mp__check "asdf $plugin_name" "is installed"
  else
    mp__info "asdf $plugin_name" "is not installed. Installing now."
    $installation_function_name
  fi
}

function mp__asdf_plugin_add_ruby {
  mp__asdf_ensure_installed
  mp__brew__ensure_package_installed ruby-build \
                                     openssl \
                                     libyaml \
                                     libffi
  asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git
}

function mp__asdf_plugin_add_nodejs {
  mp__asdf_ensure_installed
  mp__brew__ensure_package_installed coreutils gpg gnupg gnupg2
  asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
  bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring
}

function mp__asdf_plugin_add_erlang {
  mp__brew__ensure_package_installed autoconf wxmac
  asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
}

function mp__asdf_plugin_add_elixir {
  mp__brew__ensure_package_installed unzip
  asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git
}

function mp__asdf__is_version_installed {
  plugin_name="$1"
  version="$2"

  asdf list "$plugin_name" | grep "$version" 1>/dev/null
}

function mp__asdf__install_latest_version_globally {
  plugin_name="$1"

  latest_version=$(asdf latest "$plugin_name" | xargs)

  if mp__asdf__is_version_installed "$plugin_name" "$latest_version"; then
    mp__check "asdf $plugin_name $latest_version" "is installed"
  else
    mp__info "asdf $plugin_name $latest_version" "is not installed. Installing now"
    asdf install "$plugin_name" "$latest_version"
    asdf global "$plugin_name" "$latest_version"
  fi
}

##### MAS (APP STORE APPS) ####################################################

function mp__mas_install {
  mp__brew__ensure_installed
  brew install mas
}

function mp__mas_is_installed {
  mp__command_is_installed "mas"
}

function mp__mas_ensure_installed {
  mp__check_command_installed "mas" "mp__mas_is_installed" "mp__mas_install"
}

function mp__mas__app_is_installed {
  app_id="$1"

  mas list | grep "$app_id " 1>/dev/null
}

##### RUBY ####################################################################
function mp__ruby_install {
  mp__asdf__plugin_ensure_installed "ruby" "mp__asdf_plugin_add_ruby"
  mp__asdf__install_latest_version_globally "ruby"
}

##### NODEJS ##################################################################
function mp__nodejs_install {
  mp__asdf__plugin_ensure_installed "nodejs" "mp__asdf_plugin_add_nodejs"
  mp__asdf__install_latest_version_globally "nodejs"
}

##### NODEJS ##################################################################
function mp__elixir_install {
  mp__asdf__plugin_ensure_installed "erlang" "mp__asdf_plugin_add_erlang"
  mp__asdf__install_latest_version_globally "erlang"
  mp__asdf__plugin_ensure_installed "elixir" "mp__asdf_plugin_add_elixir"
  mp__asdf__install_latest_version_globally "elixir"
}

##### Brew bundle install #####################################################
function mp__brew_bundle_install {
  mp__brew__ensure_installed
  mp__download_auxiliary_file Brewfile
  brew bundle --file ~/Brewfile
}

##### Downloading and installing custom app ###################################
function mp__app_is_installed {
  app_name="$1"

  test -f "/Applications/$app_name.app"
}

function mp__download_and_install_pkg {
  app_name="$1"
  page_url="$2"
  xpath="$3"
  package_file_name="$4"

  mp__brew__ensure_package_installed wget
  mp__download_auxiliary_file httpquery
  chmod +x httpquery
  download_url=$(./httpquery "$page_url" "$xpath")
  download_filename=$(basename "$download_url")
  volume_name=$(basename "$app_name" ".app")
  download_path="~/Downloads/$download_filename"
  mkdir -p $(dirname "$download_path")
  wget -O "$download_path" "$download_url"
  echo "Downloading $download_url to $download_path"
  sudo hdiutil attach "$download_path"
  sudo installer -package "/Volumes/$volume_name/$package_file_name" -target /
  sudo hdiutil detach "/Volumes/$volume_name"
}

function mp__ensure_pkg_installed {
  app_name="$1"
  page_url="$2"
  download_url_selection_xpath="$3"
  pkg_file_name="$4"

  if mp__app_is_installed "$app_name"; then
    mp__check "$app_name" "is installed"
  else
    mp__info "$app_name" "is not installed. Installing now."
    mp__download_and_install_pkg "$app_name" "$page_url" "$download_url_selection_xpath" "$pkg_file_name"
  fi
}

##### ZSH #####################################################################
function mp__zsh_is_installed {
  test -d ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}
}

function mp__zsh_install {
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
  git clone https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k
  p10k configure
}

function mp__zsh_ensure_installed {
  if mp__zsh_is_installed; then
    mp__check "ZSH" "is installed"
  else
    mp__info "ZSH" "is not installed. Installing now."
    mp__zsh_install
  fi
}

##### PROVISIONING ############################################################

mp__ruby_install
mp__nodejs_install
mp__elixir_install

mp__brew_bundle_install
mp__zsh_ensure_installed

mp__ensure_pkg_installed "Dante Virtual Soundcard.app" \
                         "https://my.audinate.com/content/dante-virtual-soundcard-v4123-macos" \
                         "//a[starts-with(@type, 'application/x-apple-diskimage')]/@href" \
                         "DanteVirtualSoundcard.pkg"

mp__ensure_pkg_installed "Splashtop XDisplay.app" \
                         "https://www.splashtop.com/en-gb/wiredxdisplay" \
                         "//a[ends-with(@href, '.dmg')]/@href" \
                         "Splashtop XDisplay.pkg"

##### MAC PREFERENCES #########################################################

# General
  # Close any open System Preferences panes, to prevent them from overriding
  # settings we’re about to change
  osascript -e 'tell application "System Preferences" to quit'

  # Ask for the administrator password upfront
  sudo -v

  # Disable Notification Center and remove the menu bar icon
  launchctl unload -w /System/Library/LaunchAgents/com.apple.notificationcenterui.plist 2> /dev/null

  # Disable the sound effects on boot
  sudo nvram SystemAudioVolume=" "

  # Show all icons in status bar
  defaults write com.apple.systemuiserver menuExtras -array \
  "/System/Library/CoreServices/Menu Extras/AirPort.menu" \
  "/System/Library/CoreServices/Menu Extras/Bluetooth.menu" \
  "/System/Library/CoreServices/Menu Extras/Clock.menu" \
  "/System/Library/CoreServices/Menu Extras/Displays.menu" \
  "/System/Library/CoreServices/Menu Extras/Volume.menu" \
  "/System/Library/CoreServices/Menu Extras/TimeMachine.menu" \
  "/System/Library/CoreServices/Menu Extras/Battery.menu"

# Finder
  # Show hidden files
  defaults write com.apple.finder AppleShowAllFiles YES

  # Show icons for hard drives, servers, and removable media on the desktop
  defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false
  defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
  defaults write com.apple.finder ShowMountedServersOnDesktop -bool false
  defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

  # Finder: show all filename extensions
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true

  # Finder: show status bar
  defaults write com.apple.finder ShowStatusBar -bool true

  # Finder: show path bar
  defaults write com.apple.finder ShowPathbar -bool true

  # Display full POSIX path as Finder window title
  defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

  # Keep folders on top when sorting by name
  defaults write com.apple.finder _FXSortFoldersFirst -bool true

  # Use list view in all Finder windows by default
  # Four-letter codes for the other view modes: `icnv`, `clmv`, `glyv`
  defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

  # Enable AirDrop over Ethernet and on unsupported Macs running Lion
  defaults write com.apple.NetworkBrowser BrowseAllInterfaces -bool true

  # Show the /Volumes folder
  sudo chflags nohidden /Volumes

  # Disable the warning when changing a file extension
  defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

  killall Finder

# Dock
  # Autohide the dock
  defaults write com.apple.Dock autohide -bool TRUE
  killall Dock

# Menuextra
  # Show battery percentage in status bar
  defaults write com.apple.menuextra.battery ShowPercent -string YES
  # Show full date and time in status bar
  defaults write com.apple.menuextra.clock DateFormat -string "EEE d MMM  HH:mm"

# Hot corners
  # Top left screen corner → Mission Control
  defaults write com.apple.dock wvous-tl-corner -int 2
  defaults write com.apple.dock wvous-tl-modifier -int 0

# Energy
  # System Preferences > Desktop & Screen Saver > Start after: Never
  defaults -currentHost write com.apple.screensaver idleTime -int 0

  # Enable lid wakeup
  sudo pmset -a lidwake 1

  # Restart automatically on power loss
  sudo pmset -a autorestart 1

  # Restart automatically if the computer freezes
  sudo systemsetup -setrestartfreeze on

# Input
  # Set a blazingly fast keyboard repeat rate
  defaults write NSGlobalDomain KeyRepeat -int 1
  defaults write NSGlobalDomain InitialKeyRepeat -int 10

  # Use scroll gesture with the Ctrl (^) modifier key to zoom
  defaults write com.apple.universalaccess closeViewScrollWheelToggle -bool true
  defaults write com.apple.universalaccess HIDScrollZoomModifierMask -int 262144
  # Follow the keyboard focus while zoomed in
  defaults write com.apple.universalaccess closeViewZoomFollowsFocus -bool true
