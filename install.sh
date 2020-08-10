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
  mp__log "ℹ️" "$1" "$2"
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
    mp__info "$2" "is not installed. Installing now."
    $3
  fi
}

##### X-CODE ##################################################################
function mp__xcode_cli__is_installed {
  xcode-select -p 1>/dev/null
}

function mp__xcode_cli__install {
  xcode-select --install
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
    mp__info "asdf $2" "is not installed. Installing now."
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
function mp__asdf__install_latest_version_globally {
  latest_version=$(asdf latest "$1" | xargs)
  asdf install "$1" "$latest_version"
  asdf global "$1" "$latest_version"
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
      mp__check "brew $app_id" "is installed"
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
  gem install bundler
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

##### PROVISIONING ############################################################

mp__ruby_install
mp__nodejs_install
mp__elixir_install

mp__brew__ensure_package_installed chromedriver \
                                   elasticsearch \
                                   git \
                                   hub \
                                   imagemagick \
                                   openssl \
                                   postgresql \
                                   redis \
                                   sqlite \
                                   telnet \
                                   wget \
                                   yarn

mp__brew__ensure_cask_package_installed google-chrome \
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

mp__mas__ensure_app_installed 497799835  \  # Xcode
                              634159523  \  # MainStage
                              597790822  \  # SSH Proxy
                              668208984  \  # GIPHY CAPTURE
                              926036361  \  # LastPass
                              1483255076 \  # Lockdown
                              506189836  \  # Harvest
                              1518425043 \  # Boop
