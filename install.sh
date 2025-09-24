#!/bin/bash
echo "Installing brew"
export NONINTERACTIVE=1 
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
if [ "$(uname)" = "Linux" ]; then
  test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
  test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  echo "eval \"\$($(brew --prefix)/bin/brew shellenv)\"" >> ~/.bashrc
  echo "eval \"\$($(brew --prefix)/bin/brew shellenv)\"" >> ~/.zshrc
fi

echo "Installing packages"
brew install rsync tmux btop ripgrep zsh neovim lua-language-server sst/tap/opencode && \
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm && \
  git clone https://github.com/NvChad/starter ~/.config/nvim && \
  go install github.com/justjanne/powerline-go@latest && \
  curl -fsSL https://tailscale.com/install.sh | sh && \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

echo "Installing configs"
cp .zshrc ~/ && \
  cp .tmux.conf ~/ && \
  rsync -av config/* ~/.config/

if [ ! -z "${SNOWFLAKE_PRIVATE_KEY}" ] && [ ! -z "${SNOWFLAKE_CLI_CONFIG}" ]; then
  echo "Setting up snowflake config & private key"
  mkdir -p ~/.keys ~/.snowflake && \
    echo $SNOWFLAKE_PRIVATE_KEY > ~/.keys/snowflake_private_key.pem && \
    chmod 600 ~/.keys/snowflake_private_key.pem && \
    echo $SNOWFLAKE_CLI_CONFIG > ~/.snowflake/config.toml
fi
