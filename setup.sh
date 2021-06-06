#!/usr/bin/env bash

{

if [ "$EUID" -ne 0 ]; then
  echo "Elevated privileges required; please run as root."
  exit
fi

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
    dnf upgrade -y
  elif $isAptSupported; then
    apt update && apt upgrade -y && apt autoremove -y
  else
    echo "Unable to update packages: no package manager found"
  fi
}

installPkg() {
  pkgName=$1
  if $isDnfSupported; then
    dnf install $pkgName
  elif $isAptSupported; then
    apt install $pkgName
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

# git
installIfMissing git git-all

git config --global user.name metalex9
git config --global user.email alexbainter@gmail.com
git config --global alias.s status
git config --global core.editor vim

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
  wget https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm && dnf install ./google-chrome-stable_current_x86_64.rpm && rm -f ./google-chrome-stable_current_x86_64.rpm
elif $isAptSupported; then
  wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && apt install ./google-chrome-stable_current_amd64.deb && rm -f ./google-chrome-stable_current_amd64.deb
fi

# Atom
if $isDnfSupported; then
  rpm --import https://packagecloud.io/AtomEditor/atom/gpgkey
  sh -c 'echo -e "[Atom]\nname=Atom Editor\nbaseurl=https://packagecloud.io/AtomEditor/atom/el/7/\$basearch\nenabled=1\ngpgcheck=0\nrepo_gpgcheck=1\ngpgkey=https://packagecloud.io/AtomEditor/atom/gpgkey" > /etc/yum.repos.d/atom.repo'
  dnf install atom
elif $isAptSupported; then
  wget -qO - https://packagecloud.io/AtomEditor/atom/gpgkey | apt-key add -
  sh -c 'echo "deb [arch=amd64] https://packagecloud.io/AtomEditor/atom/any/ any main" > /etc/apt/sources.list.d/atom.list'
  apt update
  apt install atom
fi

apm install autocomplete-paths
apm install busy-signal
apm install intentions
apm install language-docker
apm install linter
apm install linter-eslint
apm install linter-ui-default
apm install prettier-atom
apm install seti-icons

}
