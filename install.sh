#!/bin/bash

set -e

has() {
  type "$1" > /dev/null 2>&1
  return $?
}

if [ -z "$NVME_DIR" ]; then
  NVME_DIR="$HOME/.nvme"
fi

if ! has "curl"; then
  if has "wget"; then
    # Emulate curl with wget
    curl() {
      ARGS="$* "
      ARGS=${ARGS/-s /-q }
      ARGS=${ARGS/-o /-O }
      wget $ARGS
    }
  fi
fi

install_from_git() {
  if [ -z "$NVME_SOURCE" ]; then
    NVME_SOURCE="https://github.com/bojoer/nvm-extended.git"
  fi

  if [ -d "$NVME_DIR/.git" ]; then
    echo "=> nvme is already installed in $NVME_DIR, trying to update"
    echo -e "\r=> \c"
    cd "$NVME_DIR" && git pull 2> /dev/null || {
      echo >&2 "Failed to update nvme, run 'git pull' in $NVME_DIR yourself.."
    }
  else
    # Cloning to $NVME_DIR
    echo "=> Downloading nvme from git to '$NVME_DIR'"
    echo -e "\r=> \c"
    mkdir -p "$NVME_DIR"
    git clone "$NVME_SOURCE" "$NVME_DIR"
  fi
}

install_as_script() {
  if [ -z "$NVME_SOURCE" ]; then
    NVME_SOURCE="https://raw.github.com/bojoer/nvm-extended/master/nvme.sh"
  fi

  # Downloading to $NVME_DIR
  mkdir -p "$NVME_DIR"
  if [ -d "$NVME_DIR/nvme.sh" ]; then
    echo "=> nvme is already installed in $NVME_DIR, trying to update"
  else
    echo "=> Downloading nvme as script to '$NVME_DIR'"
  fi
  curl -s "$NVME_SOURCE" -o "$NVME_DIR/nvme.sh" || {
    echo >&2 "Failed to download '$NVME_SOURCE'.."
    return 1
  }
}

if [ -z "$METHOD" ]; then
  # Autodetect install method
  if has "git"; then
    install_from_git
  elif has "curl"; then
    install_as_script
  else
    echo >&2 "You need git, curl or wget to install nvme"
    exit 1
  fi
else
  if [ "$METHOD" = "git" ]; then
    if ! has "git"; then
      echo >&2 "You need git to install nvme"
      exit 1
    fi
    install_from_git
  fi
  if [ "$METHOD" = "script" ]; then
    if ! has "curl"; then
      echo >&2 "You need curl or wget to install nvme"
      exit 1
    fi
    install_as_script
  fi
fi

echo
 
BASH_PROFILE_FILE="$HOME/.bash_profile"
ZSHRC_PROFILE_FILE="$HOME/.zshrc"
PROFILE_FILE="$HOME/.profile"

# Detect profile file if not specified as environment variable (eg: PROFILE=~/.myprofile).
if [ -z "$PROFILE" ]; then
  if [ -f "$BASH_PROFILE_FILE" ]; then
    PROFILE="$BASH_PROFILE_FILE"
  elif [ -f "$ZSHRC_PROFILE_FILE" ]; then
    PROFILE="$ZSHRC_PROFILE_FILE"
  elif [ -f "$PROFILE_FILE" ]; then
    PROFILE="$PROFILE_FILE"
  fi
fi

SOURCE_STR="# This loads nvme in a shell *as a function*\r\n"
SOURCE_STR.="[ -s \"$NVME_DIR/nvme.sh\" ] && source \"$NVME_DIR/nvme.sh\"\r\n"

if [ -z "$PROFILE" ] || [ ! -f "$PROFILE" ]; then
  if [ -z $PROFILE ]; then
    echo "=> Profile file not found. Tried ""/.bash_profile ~/.zshrc and ~/.profile."
    # @TODO: BOJOER => 2014-04-18: Implement question to create a profile file with the provided profile file name, if any, or suggest a name with option for new name input.
	echo "=> Create one of them and run this script again"
  else
	# @TODO: BOJOER => 2014-04-18: Implement test if a profile name was provided and handle exceptions.
    echo "=> The provided profile file name $PROFILE was not found or an error occured."
    echo "=> Create it (touch $PROFILE) and run this script again with the same installation arguments"
  fi
  echo "   OR"
  echo "=> Append the following lines to the correct profile or shell configuration file yourself:"
  echo
  echo "   $SOURCE_STR"
  echo
else
  if ! grep -qc 'nvme.sh' $PROFILE; then
    echo "=> Appending source string to $PROFILE"
    echo "" >> "$PROFILE"
    echo $SOURCE_STR >> "$PROFILE"
	echo "=> There were no problems during installation so nvme command should work."
  else
    echo "=> Source string already present in $PROFILE."
  fi
  source $PROFILE
  echo "=> If it does not work try closing and reopening your shell"
  echo "   OR"
  echo "=> If the Source String was already present in $PROFILE:"
  echo "=>   - make sure it points to the latest nvme installation and restart your shell"
  echo "=>   - remove all relevant lines that contain the word \"nvme\" and run the script again"
fi