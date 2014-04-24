# Node Version Manager Extended
# Implemented as a bash function
# To use source this file from your bash profile
#
# Implemented and maintained by Joeri Boudewijns <bojoer@icloud.com>
#
# Extended version of the implementation of NVM
# by Tim Caswell <tim@creationix.com> up till v0.4.0
# with much bash help from Matthew Ranney

NVME_SCRIPT_SOURCE="$_"

nvme_has() {
  type "$1" > /dev/null 2>&1
  return $?
}

# Make zsh glob matching behave same as bash
# This fixes the "zsh: no matches found" errors
if nvme_has "unsetopt"; then
  unsetopt nomatch 2>/dev/null
  NVME_CD_FLAGS="-q"
fi

# Auto detect the NVME_DIR when not set
if [ -z "$NVME_DIR" ]; then
  if [ -n "$BASH_SOURCE" ]; then
    NVME_SCRIPT_SOURCE="${BASH_SOURCE[0]}"
  fi
  export NVME_DIR=$(cd $NVME_CD_FLAGS $(dirname "${NVME_SCRIPT_SOURCE:-$0}") > /dev/null && pwd)
fi
unset NVME_SCRIPT_SOURCE 2> /dev/null


# Setup mirror location if not already set
if [ -z "$NVME_NODEJS_ORG_MIRROR" ]; then
  export NVME_NODEJS_ORG_MIRROR="http://nodejs.org/dist"
fi

# Obtain nvme version from rc file
nvme_rc_version() {
  if [ -e .nvmerc ]; then
    NVME_RC_VERSION=`cat .nvmerc | head -n 1`
    echo "Found .nvmerc files with version <$NVME_RC_VERSION>"
  fi
}

# Expand a version using the version cache
nvme_version() {
  local PATTERN=$1
  local VERSION
  # The default version is the current one
  if [ -z "$PATTERN" ]; then
    PATTERN='current'
  fi

  VERSION=`nvme_ls $PATTERN | tail -n1`
  echo "$VERSION"

  if [ "$VERSION" = 'N/A' ]; then
    return
  fi
}

nvme_remote_version() {
  local PATTERN=$1
  local VERSION
  VERSION=`nvme_ls_remote $PATTERN | tail -n1`
  echo "$VERSION"

  if [ "$VERSION" = 'N/A' ]; then
    return
  fi
}

nvme_normalize_version() {
  echo "$1" | sed -e 's/^v//' | awk -F. '{ printf("%d%03d%03d\n", $1,$2,$3); }'
}

nvme_format_version() {
  echo "$1" | sed -e 's/^\([0-9]\)/v\1/g'
}
  
nvme_binary_available() {
  # binaries started with node 0.8.6
  local MINIMAL="0.8.6"
  local VERSION=$1
  [ $(nvme_normalize_version $VERSION) -ge $(nvme_normalize_version $MINIMAL) ]
}

nvme_ls() {
  local PATTERN=$1
  local VERSIONS=''
  if [ "$PATTERN" = 'current' ]; then
    echo `node -v 2>/dev/null`
    return
  fi

  if [ -f "$NVME_DIR/alias/$PATTERN" ]; then
    nvme_version `cat $NVME_DIR/alias/$PATTERN`
    return
  fi
  # If it looks like an explicit version, don't do anything funny
  if [ `expr "$PATTERN" : "v[[:digit:]]*\.[[:digit:]]*\.[[:digit:]]*$"` != 0 ]; then
    VERSIONS="$PATTERN"
  else
    VERSIONS=`find "$NVME_DIR/" -maxdepth 1 -type d -name "$(nvme_format_version $PATTERN)*" -exec basename '{}' ';' \
      | sort -t. -u -k 1.2,1n -k 2,2n -k 3,3n`
  fi
  if [ -z "$VERSIONS" ]; then
      echo "N/A"
      return
  fi
  echo "$VERSIONS"
  return
}

nvme_ls_remote() {
  local PATTERN=$1
  local VERSIONS
  local GREP_OPTIONS=''
  if [ -n "$PATTERN" ]; then
    PATTERN=`nvme_format_version "$PATTERN"`
  else
    PATTERN=".*"
  fi
  VERSIONS=`curl -s $NVME_NODEJS_ORG_MIRROR/ \
              | \egrep -o 'v[0-9]+\.[0-9]+\.[0-9]+' \
              | \grep -w "${PATTERN}" \
              | sort -t. -u -k 1.2,1n -k 2,2n -k 3,3n`
  if [ -z "$VERSIONS" ]; then
    echo "N/A"
    return
  fi
  echo "$VERSIONS"
  return
}

nvme_checksum() {
  if nvme_has "shasum"; then
    checksum=$(shasum $1 | awk '{print $1}')
  elif nvme_has "sha1"; then
    checksum=$(sha1 -q $1)
  else
    checksum=$(sha1sum $1 | awk '{print $1}')
  fi

  if [ "$checksum" = "$2" ]; then
    return
  elif [ -z "$2" ]; then
    echo 'Checksums empty' #missing in raspberry pi binary
    return
  else
    echo 'Checksums do not match.'
    return 1
  fi
}

nvme_print_versions() {
  local VERSION
  local FORMAT
  local CURRENT=`nvme_version current`
  echo "$1" | while read VERSION; do
    if [ "$VERSION" = "$CURRENT" ]; then
      FORMAT='\033[0;32m-> %9s\033[0m'
    elif [ -d "$NVME_DIR/$VERSION" ]; then
      FORMAT='\033[0;34m%12s\033[0m'
    else
      FORMAT='%12s'
    fi
    printf "$FORMAT\n" $VERSION
  done
}

nvme() {
  if [ $# -lt 1 ]; then
    nvme help
    return
  fi

  # Try to figure out the os and arch for binary fetching
  local uname="$(uname -a)"
  local os=
  local arch="$(uname -m)"
  local GREP_OPTIONS=''
  case "$uname" in
    Linux\ *) os=linux ;;
    Darwin\ *) os=darwin ;;
    SunOS\ *) os=sunos ;;
    FreeBSD\ *) os=freebsd ;;
  esac
  case "$uname" in
    *x86_64*) arch=x64 ;;
    *i*86*) arch=x86 ;;
    *armv6l*) arch=arm-pi ;;
  esac

  # initialize local variables
  local VERSION
  local ADDITIONAL_PARAMETERS
  local ALIAS

  case $1 in
    "help" )
      echo
      echo "Node Version Manager"
      echo
      echo "Usage:"
      echo "    nvme help                    Show this message"
      echo "    nvme --version               Print out the latest released version of nvme"
      echo "    nvme install [-s] <version>  Download and install a <version>, [-s] from source"
      echo "    nvme uninstall <version>     Uninstall a version"
      echo "    nvme use <version>           Modify PATH to use <version>"
      echo "    nvme run <version> [<args>]  Run <version> with <args> as arguments"
      echo "    nvme current                 Display currently activated version"
      echo "    nvme ls                      List installed versions"
      echo "    nvme ls <version>            List versions matching a given description"
      echo "    nvme ls-remote               List remote versions available for install"
      echo "    nvme deactivate              Undo effects of NVM Extended on current shell"
      echo "    nvme alias [<pattern>]       Show all aliases beginning with <pattern>"
      echo "    nvme alias <name> <version>  Set an alias named <name> pointing to <version>"
      echo "    nvme unalias <name>          Deletes the alias named <name>"
      echo "    nvme copy-packages <version> Install global NPM packages contained in <version> to current version"
      echo
      echo "Example:"
      echo "    nvme install v0.10.24        Install a specific version number"
      echo "    nvme use 0.10                Use the latest available 0.10.x release"
      echo "    nvme run 0.10.24 myApp.js    Run myApp.js using node v0.10.24"
      echo "    nvme alias default 0.10.24   Set default node version on a shell"
      echo
      echo "Note:"
      echo "    to remove, delete or uninstall nvme - just remove ~/.nvm-extended, ~/.npm and ~/.bower folders"
      echo
    ;;

    "install" )
      # initialize local variables
      local binavail
      local t
      local url
      local sum
      local tarball
      local nobinary

      if ! nvme_has "curl"; then
        echo 'NVM Extended Needs curl to proceed.' >&2;
        return 1
      fi

      if [ $# -lt 2 ]; then
        nvme help
        return
      fi

      shift

      nobinary=0
      if [ "$1" = "-s" ]; then
        nobinary=1
        shift
      fi

      if [ "$os" = "freebsd" ]; then
        nobinary=1
      fi

      [ -d "$NVME_DIR/$1" ] && echo "$1 is already installed." && return

      VERSION=`nvme_remote_version $1`
      ADDITIONAL_PARAMETERS=''

      shift

      while [ $# -ne 0 ]
      do
        ADDITIONAL_PARAMETERS="$ADDITIONAL_PARAMETERS $1"
        shift
      done

      [ -d "$NVME_DIR/$VERSION" ] && echo "$VERSION is already installed." && return

      # skip binary install if no binary option specified.
      if [ $nobinary -ne 1 ]; then
        # shortcut - try the binary if possible.
        if [ -n "$os" ]; then
          if nvme_binary_available "$VERSION"; then
            t="$VERSION-$os-$arch"
            url="$NVME_NODEJS_ORG_MIRROR/$VERSION/node-${t}.tar.gz"
            sum=`curl -s $NVME_NODEJS_ORG_MIRROR/$VERSION/SHASUMS.txt | \grep node-${t}.tar.gz | awk '{print $1}'`
            local tmpdir="$NVME_DIR/bin/node-${t}"
            local tmptarball="$tmpdir/node-${t}.tar.gz"
            if (
              mkdir -p "$tmpdir" && \
              curl -L -C - --progress-bar $url -o "$tmptarball" && \
              nvme_checksum "$tmptarball" $sum && \
              tar -xzf "$tmptarball" -C "$tmpdir" --strip-components 1 && \
              rm -f "$tmptarball" && \
              mv "$tmpdir" "$NVME_DIR/$VERSION"
              )
            then
              nvme use $VERSION
              return;
            else
              echo "Binary download failed, trying source." >&2
              rm -rf "$tmptarball" "$tmpdir"
            fi
          fi
        fi
      fi

      echo "Additional options while compiling: $ADDITIONAL_PARAMETERS"

      tarball=''
      sum=''
      make='make'
      if [ "$os" = "freebsd" ]; then
        make='gmake'
        MAKE_CXX="CXX=c++"
      fi
      local tmpdir="$NVME_DIR/src"
      local tmptarball="$tmpdir/node-$VERSION.tar.gz"
      if [ "`curl -Is "$NVME_NODEJS_ORG_MIRROR/$VERSION/node-$VERSION.tar.gz" | \grep '200 OK'`" != '' ]; then
        tarball="$NVME_NODEJS_ORG_MIRROR/$VERSION/node-$VERSION.tar.gz"
        sum=`curl -s $NVME_NODEJS_ORG_MIRROR/$VERSION/SHASUMS.txt | \grep node-$VERSION.tar.gz | awk '{print $1}'`
      elif [ "`curl -Is "$NVME_NODEJS_ORG_MIRROR/node-$VERSION.tar.gz" | \grep '200 OK'`" != '' ]; then
        tarball="$NVME_NODEJS_ORG_MIRROR/node-$VERSION.tar.gz"
      fi
      if (
        [ -n "$tarball" ] && \
        mkdir -p "$tmpdir" && \
        curl -L --progress-bar $tarball -o "$tmptarball" && \
        nvme_checksum "$tmptarball" $sum && \
        tar -xzf "$tmptarball" -C "$tmpdir" && \
        cd "$tmpdir/node-$VERSION" && \
        ./configure --prefix="$NVME_DIR/$VERSION" $ADDITIONAL_PARAMETERS && \
        $make $MAKE_CXX && \
        rm -f "$NVME_DIR/$VERSION" 2>/dev/null && \
        $make $MAKE_CXX install
        )
      then
        nvme use $VERSION
        if ! nvme_has "npm" ; then
          echo "Installing npm..."
          if [ "`expr "$VERSION" : '\(^v0\.1\.\)'`" != '' ]; then
            echo "npm requires node v0.2.3 or higher"
          elif [ "`expr "$VERSION" : '\(^v0\.2\.\)'`" != '' ]; then
            if [ "`expr "$VERSION" : '\(^v0\.2\.[0-2]$\)'`" != '' ]; then
              echo "npm requires node v0.2.3 or higher"
            else
              curl https://npmjs.org/install.sh | clean=yes npm_install=0.2.19 sh
            fi
          else
            curl https://npmjs.org/install.sh | clean=yes sh
          fi
        fi
      else
        echo "nvme: install $VERSION failed!"
        return 1
      fi
    ;;
    "uninstall" )
      [ $# -ne 2 ] && nvme help && return
      PATTERN=`nvme_format_version $2`
      if [ "$PATTERN" = `nvme_version` ]; then
        echo "nvme: Cannot uninstall currently-active node version, $PATTERN."
        return 1
      fi
      VERSION=`nvme_version $PATTERN`
      if [ ! -d $NVME_DIR/$VERSION ]; then
        echo "$VERSION version is not installed..."
        return;
      fi

      t="$VERSION-$os-$arch"

      # Delete all files related to target version.
      rm -rf "$NVME_DIR/src/node-$VERSION" \
             "$NVME_DIR/src/node-$VERSION.tar.gz" \
             "$NVME_DIR/bin/node-${t}" \
             "$NVME_DIR/bin/node-${t}.tar.gz" \
             "$NVME_DIR/$VERSION" 2>/dev/null
      echo "Uninstalled node $VERSION"

      # Rm any aliases that point to uninstalled version.
      for ALIAS in `\grep -l $VERSION $NVME_DIR/alias/* 2>/dev/null`
      do
        nvme unalias `basename $ALIAS`
      done

    ;;
    "deactivate" )
      if [ `expr "$PATH" : ".*$NVME_DIR/.*/bin.*"` != 0 ] ; then
        export PATH=${PATH%$NVME_DIR/*/bin*}${PATH#*$NVME_DIR/*/bin:}
        hash -r
        echo "$NVME_DIR/*/bin removed from \$PATH"
      else
        echo "Could not find $NVME_DIR/*/bin in \$PATH"
      fi
      if [ `expr "$MANPATH" : ".*$NVME_DIR/.*/share/man.*"` != 0 ] ; then
        export MANPATH=${MANPATH%$NVME_DIR/*/share/man*}${MANPATH#*$NVME_DIR/*/share/man:}
        echo "$NVME_DIR/*/share/man removed from \$MANPATH"
      else
        echo "Could not find $NVME_DIR/*/share/man in \$MANPATH"
      fi
      if [ `expr "$NODE_PATH" : ".*$NVME_DIR/.*/lib/node_modules.*"` != 0 ] ; then
        export NODE_PATH=${NODE_PATH%$NVME_DIR/*/lib/node_modules*}${NODE_PATH#*$NVME_DIR/*/lib/node_modules:}
        echo "$NVME_DIR/*/lib/node_modules removed from \$NODE_PATH"
      else
        echo "Could not find $NVME_DIR/*/lib/node_modules in \$NODE_PATH"
      fi
    ;;
    "use" )
      if [ $# -eq 0 ]; then
        nvme help
        return
      fi
      if [ $# -eq 1 ]; then
        nvme_rc_version
        if [ -n "$NVME_RC_VERSION" ]; then
            VERSION=`nvme_version $NVME_RC_VERSION`
        fi
      else
        VERSION=`nvme_version $2`
      fi
      if [ -z "$VERSION" ]; then
        nvme help
        return
      fi
      if [ -z "$VERSION" ]; then
        VERSION=`nvme_version $2`
      fi
      if [ ! -d "$NVME_DIR/$VERSION" ]; then
        echo "$VERSION version is not installed yet"
        return 1
      fi
      if [ `expr "$PATH" : ".*$NVME_DIR/.*/bin"` != 0 ]; then
        PATH=${PATH%$NVME_DIR/*/bin*}$NVME_DIR/$VERSION/bin${PATH#*$NVME_DIR/*/bin}
      else
        PATH="$NVME_DIR/$VERSION/bin:$PATH"
      fi
      if [ -z "$MANPATH" ]; then
        MANPATH=$(manpath)
      fi
      MANPATH=${MANPATH#*$NVME_DIR/*/man:}
      if [ `expr "$MANPATH" : ".*$NVME_DIR/.*/share/man"` != 0 ]; then
        MANPATH=${MANPATH%$NVME_DIR/*/share/man*}$NVME_DIR/$VERSION/share/man${MANPATH#*$NVME_DIR/*/share/man}
      else
        MANPATH="$NVME_DIR/$VERSION/share/man:$MANPATH"
      fi
      if [ `expr "$NODE_PATH" : ".*$NVME_DIR/.*/lib/node_modules.*"` != 0 ]; then
        NODE_PATH=${NODE_PATH%$NVME_DIR/*/lib/node_modules*}$NVME_DIR/$VERSION/lib/node_modules${NODE_PATH#*$NVME_DIR/*/lib/node_modules}
      else
        NODE_PATH="$NVME_DIR/$VERSION/lib/node_modules:$NODE_PATH"
      fi
      export PATH
      hash -r
      export MANPATH
      export NODE_PATH
      export NVME_PATH="$NVME_DIR/$VERSION/lib/node"
      export NVME_BIN="$NVME_DIR/$VERSION/bin"
      echo "Now using node $VERSION"
    ;;
    "run" )
      # run given version of node
      if [ $# -lt 2 ]; then
        nvme help
        return
      fi
      VERSION=`nvme_version $2`
      if [ ! -d "$NVME_DIR/$VERSION" ]; then
        echo "$VERSION version is not installed yet"
        return;
      fi
      if [ `expr "$NODE_PATH" : ".*$NVME_DIR/.*/lib/node_modules.*"` != 0 ]; then
        RUN_NODE_PATH=${NODE_PATH%$NVME_DIR/*/lib/node_modules*}$NVME_DIR/$VERSION/lib/node_modules${NODE_PATH#*$NVME_DIR/*/lib/node_modules}
      else
        RUN_NODE_PATH="$NVME_DIR/$VERSION/lib/node_modules:$NODE_PATH"
      fi
      echo "Running node $VERSION"
      NODE_PATH=$RUN_NODE_PATH $NVME_DIR/$VERSION/bin/node "${@:3}"
    ;;
    "ls" | "list" )
      nvme_print_versions "`nvme_ls $2`"
      if [ $# -eq 1 ]; then
        nvme alias
      fi
      return
    ;;
    "ls-remote" | "list-remote" )
        nvme_print_versions "`nvme_ls_remote $2`"
        return
    ;;
    "current" )
      nvme_version current
    ;;
    "alias" )
      mkdir -p $NVME_DIR/alias
      if [ $# -le 2 ]; then
        local DEST
        for ALIAS in $NVME_DIR/alias/$2*; do
          if [ -e "$ALIAS" ]; then
            DEST=`cat $ALIAS`
            VERSION=`nvme_version $DEST`
            if [ "$DEST" = "$VERSION" ]; then
                echo "$(basename $ALIAS) -> $DEST"
            else
                echo "$(basename $ALIAS) -> $DEST (-> $VERSION)"
            fi
          fi
        done
        return
      fi
      if [ -z "$3" ]; then
          rm -f $NVME_DIR/alias/$2
          echo "$2 -> *poof*"
          return
      fi
      mkdir -p $NVME_DIR/alias
      VERSION=`nvme_version $3`
      if [ $? -ne 0 ]; then
        echo "! WARNING: Version '$3' does not exist." >&2
      fi
      echo $3 > "$NVME_DIR/alias/$2"
      if [ ! "$3" = "$VERSION" ]; then
          echo "$2 -> $3 (-> $VERSION)"
      else
        echo "$2 -> $3"
      fi
    ;;
    "unalias" )
      mkdir -p $NVME_DIR/alias
      [ $# -ne 2 ] && nvme help && return
      [ ! -f "$NVME_DIR/alias/$2" ] && echo "Alias $2 doesn't exist!" && return
      rm -f $NVME_DIR/alias/$2
      echo "Deleted alias $2"
    ;;
    "copy-packages" )
        if [ $# -ne 2 ]; then
          nvme help
          return
        fi
        VERSION=`nvme_version $2`
        local ROOT=`(nvme use $VERSION && npm -g root)`
        local ROOTDEPTH=$((`echo $ROOT | sed 's/[^\/]//g'|wc -m` -1))

        # declare local INSTALLS first, otherwise it doesn't work in zsh
        local INSTALLS
        INSTALLS=`nvme use $VERSION > /dev/null && npm -g -p ll | \grep "$ROOT\/[^/]\+$" | cut -d '/' -f $(($ROOTDEPTH + 2)) | cut -d ":" -f 2 | \grep -v npm | tr "\n" " "`

        npm install -g ${INSTALLS[@]}
    ;;
    "clear-cache" )
        rm -f $NVME_DIR/v* 2>/dev/null
        echo "Cache cleared."
    ;;
    "version" )
        nvme_version $2
    ;;
    "--version" )
        echo "nvme v0.1.0"
    ;;
    * )
      nvme help
    ;;
  esac
}

nvme ls default >/dev/null && nvme use default >/dev/null || true

