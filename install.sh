#!/bin/bash
set -eo pipefail

##### GENERIC #################################################################

# arg 1 - command name
function mp__command_is_installed {
  type "$1" >/dev/null 2>&1
}

# arg 1 - emoji
# arg 2 - module name
# arg 3 - log text
function mp__log {
  echo "$1 [$2] $3"
}

# arg 1 - module name
# arg 2 - log text
function mp__info {
  mp__log "ℹ️ " "$1" "$2"
}

# arg 1 - module name
# arg 2 - log text
function mp__check {
  mp__log "✅" "$1" "$2"
}

# arg 1 - module name
# arg 2 - function name to check installation status
# arg 3 - function name to execute installation
function mp__check_command_installed {
  if $($2); then
    mp__check "$1" "is installed"
  else
    mp__info "$1" "is not installed. Installing now."
    $3
  fi
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

  # Install ZSH completions
  if type brew &>/dev/null; then
    FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH

    autoload -Uz compinit
    compinit
  fi
}

function mp__brew__is_installed {
  mp__command_is_installed "brew"
}

function mp__brew__ensure_installed {
  mp__check_command_installed "brew" "mp__brew__is_installed" "mp__brew__install"
}

# arg 1 - plugin name
function mp__brew__package_is_installed {
  brew list -1 | grep "$1" 1>/dev/null
}

# args - package names
function mp__brew__ensure_package_installed {
  mp__brew__ensure_installed

  for name in "$@"
  do
    if mp__brew__package_is_installed $name; then
      mp__check "brew $name" "is installed"
    else
      mp__info "brew $name" "is not installed. Installing now."
      brew install $name
    fi
  done
}

# arg 1 - service name
function mp__brew__service_is_running {
  brew services list | grep "$1" | grep started 1>/dev/null
}

# args - service names
function mp__brew__ensure_service_running {
  for name in "$@"
  do
    if mp__brew__service_is_running $name; then
      mp__check "brew $name" "is running"
    else
      mp__info "brew $name" "is not running. Starting now."
      brew services start $name
    fi
  done
}

# arg 1 - plugin name
function mp__brew__cask_package_is_installed {
  brew cask list -1 | grep "$1" 1>/dev/null
}

# args - package names
function mp__brew__ensure_cask_package_installed {
  mp__brew__ensure_installed

  for name in "$@"
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
                                     curl \
                                     asdf
  echo -e "\n. $(brew --prefix asdf)/asdf.sh" >> ~/.zshrc
}

function mp__asdf_is_installed {
  mp__command_is_installed "asdf"
}

function mp__asdf_ensure_installed {
  mp__check_command_installed "asdf" "mp__asdf_is_installed" "mp__asdf_install"
}

# arg 1 - plugin name
function mp__asdf_plugin_is_installed {
  asdf plugin-list | grep "$1" 1>/dev/null
}

# arg 1 - asdf plugin name to check
# arg 2 - function name to install plugin
function mp__asdf__plugin_ensure_installed {
  mp__asdf_ensure_installed

  if $(mp__asdf_plugin_is_installed "$1"); then
    mp__check "asdf $1" "is installed"
  else
    mp__info "asdf $1" "is not installed. Installing now."
    $2
  fi
}

function mp__asdf_plugin_add_ruby {
  mp__asdf_ensure_installed
  mp__brew__ensure_package_installed ruby-build \
                                     openssl \
                                     libyaml \
                                     libffi
  asdf plugin-add ruby https://github.com/asdf-vm/asdf-ruby.git
}

function mp__asdf_plugin_add_nodejs {
  mp__asdf_ensure_installed
  mp__brew__ensure_package_installed coreutils gpg
  asdf plugin-add nodejs https://github.com/asdf-vm/asdf-nodejs.git
  bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring
}

function mp__asdf_plugin_add_erlang {
  mp__brew__ensure_package_installed autoconf wxmac
  asdf plugin-add erlang https://github.com/asdf-vm/asdf-erlang.git
}

function mp__asdf_plugin_add_elixir {
  mp__brew__ensure_package_installed unzip
  asdf plugin-add elixir https://github.com/asdf-vm/asdf-elixir.git
}

# arg 1 - asdf plugin name
# arg 2 -installation version
function mp__asdf__is_version_installed {
  asdf list "$1" | grep "$2" 1>/dev/null
}

# arg 1 - asdf plugin name
function mp__asdf__install_latest_version_globally {
  latest_version=$(asdf latest "$1" | xargs)

  if mp__asdf__is_version_installed "$1" "$latest_version"; then
    mp__check "asdf $1 $latest_version" "is installed"
  else
    mp__info "asdf $1 $latest_version" "is not installed. Installing now"
    asdf install "$1" "$latest_version"
    asdf global "$1" "$latest_version"
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

# arg 1 - app ID
function mp__mas__app_is_installed {
  mas list | grep "$1 " 1>/dev/null
}

# args - app IDs
function mp__mas__ensure_app_installed {
  mp__mas_ensure_installed

  for app_id in "$@"
  do
    if mp__mas__app_is_installed $app_id; then
      mp__check "mas $app_id" "is installed"
    else
      mp__info "mas $app_id" "is not installed. Installing now."
      mas install $app_id
    fi
  done
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

mp__brew__ensure_cask_package_installed java

mp__brew__ensure_package_installed elasticsearch@6 \
                                   git \
                                   gh \
                                   imagemagick \
                                   openssl \
                                   postgresql \
                                   redis \
                                   sqlite \
                                   telnet \
                                   wget \
                                   yarn

mp__brew__ensure_service_running elasticsearch@6 \
                                 postgresql \
                                 redis

mp__brew__ensure_cask_package_installed chromedriver \
                                        google-chrome \
                                        firefox \
                                        dropbox \
                                        google-backup-and-sync \
                                        docker \
                                        iterm2 \
                                        macdown \
                                        postman \
                                        spectacle \
                                        alfred \
                                        brave-browser \
                                        rubymine \
                                        slack \
                                        virtualbox \
                                        vlc \
                                        whatsapp \
                                        atom \
                                        proxifier

#                             Xcode     MainStage SSH Proxy GIPHY CAPTURE LastPass  Lockdown   Harvest   Boop
mp__mas__ensure_app_installed 497799835 634159523 597790822 668208984     926036361 1483255076 506189836 1518425043

mp__zsh_ensure_installed

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
