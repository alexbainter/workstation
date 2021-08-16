#!/usr/bin/env bash

{

# utils
getExecPath() {
  execPath=$(command -v "$1")
  echo $execPath
}

if [[ -e $(getExecPath dnf) ]]; then
  isDnfSupported=true
else
  isDnfSupported=false
fi

if [[ -e $(getExecPath apt) ]]; then
  isAptSupported=true
else
  isAptSupported=false
fi

updatePkgs() {
  if $isDnfSupported; then
    sudo dnf upgrade -y
  elif $isAptSupported; then
    sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
  else
    echo "Unable to update packages: no package manager found"
  fi
}

installPkg() {
  pkgName=$1
  if $isDnfSupported; then
    sudo dnf install $pkgName -y
  elif $isAptSupported; then
    sudo apt install $pkgName -y
  else
    echo "Unable to install $pkgName: no package manager found"
  fi
}

installIfMissing() {
  commandName=$1
  if [[ -z $2 ]]; then
    pkgName=$1
  else
    pkgName=$2
  fi

  execPath=$(getExecPath $command)

  if [[ -z execPath ]]; then
    installPkg $pkgName
  fi
}


# update packages
updatePkgs

# vim
installIfMissing vim

# neovim
installIfMissing nvim neovim
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

# git
installIfMissing git git-all

git config --global user.name metalex9
git config --global user.email alexbainter@gmail.com
git config --global alias.s status
git config --global core.editor nvim

# ssh-key
if [[ ! -e ~/.ssh/id_ed25519.pub ]]; then
  ssh-keygen -t ed25519 -C "alexbainter@gmail.com" -f ~/.ssh/id_ed25519 -N ''
  eval "$(ssh-agent -s)"
  ssh-add ~/.ssh/id_ed25519
  installIfMissing xclip
  xclip -selection clipboard < ~/.ssh/id_ed25519.pub
  echo "Key content copied to clipboard; add to Github"
  xdg-open "https://github.com/settings/ssh/new" &
fi

# nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
nvm install --lts

# Google Chrome
if $isDnfSupported; then
  wget https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm && sudo dnf -y install ./google-chrome-stable_current_x86_64.rpm && rm -f ./google-chrome-stable_current_x86_64.rpm
elif $isAptSupported; then
  wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && sudo apt -y install ./google-chrome-stable_current_amd64.deb && rm -f ./google-chrome-stable_current_amd64.deb
fi

# Docker
if $isDnfSupported; then
  sudo dnf -y install dnf-plugins-core
  sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
  sudo dnf -y install docker-ce docker-ce-cli containerd.io
elif $isAptSupported; then
  declare -A codenameMap =( ["Odin"]="focal" )
  sudo apt -y install lsb-release
  lsbCodename=$(lsb_release -cs)
  mappedCodename="${codenameMap[$lsbCodename]}"
  if [[ -n $mappedCodename ]]; then
    lsbCodename=mappedCodename
  fi
  sudo apt -y install apt-transport-https ca-certificates gnupg
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $lsbCodename stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt -y update
  sudo apt -y install docker-ce docker-ce-cli containerd.io
fi

if $isDnfSupported || $isAptSupported; then
  sudo systemctl start docker
  sudo groupadd docker
  sudo usermod -aG docker $USER
  sudo systemctl enable docker.service
  sudo systemctl enable containerd.service

  # Docker Compose
  sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  sudo curl -L https://raw.githubusercontent.com/docker/compose/1.29.2/contrib/completion/bash/docker-compose -o /etc/bash_completion.d/docker-compose
fi

# VSCode
if $isDnfSupported; then
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
  sudo dnf check-update
  sudo dnf -y install code
elif $isAptSupported; then
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
  sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
  sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
  rm -f packages.microsoft.gpg
  sudo apt -y install apt-transport-https
  sudo apt update
  sudo apt -y install code
fi

mkdir -p ~/source

curl -o- https://raw.githubusercontent.com/metalex9/dotfiles/main/setup.sh | bash
}
