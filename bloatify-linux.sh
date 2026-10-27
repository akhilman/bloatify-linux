#!/bin/bash

set -eu
# set -x

if [ $(id -u) -eq 0 ]; then
	echo This script should not be run by root.
	exit 1
fi

BASIC=false
CLANG=false
DENO=false
DESKTOP=false
DEVEL=false
DOTFILES=false
FLATPAK=false
PYTHON=false
RUST=false
UPGRADE=false
YES=false

while [ $# -gt 0 ]; do
	# Expand combined short flags: -but → -b -u -t
	case $1 in
	--*) ;; # long flag, don't expand
	-?*)
		if [ ${#1} -gt 2 ]; then
			rest=${1#-}
			shift
			while [ -n "$rest" ]; do
				set -- "$@" "-${rest%"${rest#?}"}"
				rest=${rest#?}
			done
			continue
		fi
		;;
	esac

	case $1 in
	-b | --basic) # install basic tools
		BASIC=true
		;;
	-D | --desktop) # install desktop relaited stuff (basic, desktop, dotfiles, flatpack)
		DESKTOP=true
		;;
	-d | --devel) # install development tools (basic, devel, dotfiles)
		DEVEL=true
		;;
	-c | --clang) # install clang C/C++ tools
		CLANG=true
		;;
	-n | --deno) # install Deno tools
		DENO=true
		;;
	-p | --python) # Install Python tools
		PYTHON=true
		;;
	-r | --rust) # install Rust tools
		RUST=true
		;;
	-t | --dotfiles) # install dotfiles
		DOTFILES=true
		;;
	-u | --upgrade) # upgrade everything
		UPGRADE=true
		;;
	-y | --yes) # do not ask any questions
		YES=true
		;;
	-h | --help) # show help
		echo "Usage:"
		echo "  $(basename $0) [options]"
		echo "Options:"
		cat $0 | sed -n 's/^\s*\(-\w\)|\(--\w\+\))\s\+#\s\+\(.*\)$/\t\1, \2\t\3/p'
		exit 0
		;;
	*)
		echo Unknown argument: \`$1\`
		exit 1
		;;
	esac
	shift
done

if $DESKTOP; then
	BASIC=true
	DOTFILES=true
fi

if $CLANG || $DOTFILES || $DEVEL || $DENO || $PYTHON || $RUST; then
	BASIC=true
fi

if command -v apt-get >/dev/null; then
	DISTRO=debian
elif command -v dnf >/dev/null; then
	DISTRO=fedora
elif command -v pacman >/dev/null; then
	DISTRO=arch
elif command -v zypper >/dev/null; then
	DISTRO=opensuse
else
	echo ERROR: Unsupported distro!
	exit 1
fi
echo Distro: $DISTRO

[ -f $HOME/.cargo/env ] && . $HOME/.cargo/env
[ -f $HOME/.deno/env ] && . $HOME/.deno/env
[ -f $HOME/.local/bin/env ] && . $HOME/.local/bin/env

XDG_CONFIG_DIR=${XDG_CONFIG_DIR:-$HOME/.config}
XDG_CACHE_DIR=${XDG_CACHE_DIR:-$HOME/.cache}

PACMAN_ARGS="--needed"
APT_ARGS="-o APT::Install-Suggests=0 -o APT::Install-Recommends=0"
DNF_ARGS=""
ZYPPER_ARGS=""
FLATPAK_ARGS=""
if $YES; then
	PACMAN_ARGS="$PACMAN_ARGS --noconfirm"
	APT_ARGS="$APT_ARGS -y"
	DNF_ARGS="$DNF_ARGS -y"
	ZYPPER_ARGS="$ZYPPER_ARGS -y --force-resolution"
	FLATPAK_ARGS="$FLATPAK_ARGS --assumeyes --noninteracpive"
fi

version_ge() {
	printf "%s\n%s\n" $1 $2 | sort --check=quiet --version-sort
}

deduplicate() {
	echo $(echo $@ | tr ' ' '\n' | sort -u | tr '\n' ' ')
}

if command -v run0 >/dev/null && command -v pkaction >/dev/null &&
	version_ge 127 $(pkaction --version | grep -o '[0-9]\+'); then
	SUDO=${SUDO:-run0 --pty}
else
	SUDO=${SUDO:-sudo}
fi

CARGO_PKGS=""
DISTRO_PKGS=""
DISTRO_PATTERNS=""
NPM_PKGS=""
PIP_PKGS=""

SIDEINSTALL_DENO=false
SIDEINSTALL_RUSTUP=false
SIDEINSTALL_CARGO_BINSTALL=false
SIDEINSTALL_UV=false

if $DEVEL; then
	CARGO_PKGS="$(echo $CARGO_PKGS cargo-{criterion,edit,machete,outdated,tree,expand})"
fi

if $FLATPAK; then
	DISTRO_PKGS="$DISTRO_PKGS flatpak"
fi

if $RUST; then
	CARGO_PKGS=$(echo $CARGO_PKGS cargo-{cache,update})
fi

case $DISTRO in
arch)
	if $BASIC; then
		DISTRO_PKGS=$(
			echo $DISTRO_PKGS which less curl wget gnupg fish htop unzip gettext \
				helix ripgrep codebook-lsp \
				tmux \
				mr vcsh git make
		)
		if [ -n "${WAYLAND_DISPLAY:-}" ]; then
			DISTRO_PKGS=$(
				echo $DISTRO_PKGS \
					wl-clipboard
			)
		elif [ -n "${DISPLAY:-}" ]; then
			DISTRO_PKGS=$(
				echo $DISTRO_PKGS \
					xclip
			)
		fi
		if [ "$TERM" = xterm-kitty ]; then
			DISTRO_PKGS=$(
				echo $DISTRO_PKGS \
					kitty-terminfo
			)
		fi
	fi

	if $DEVEL; then
		DISTRO_PKGS=$(
			echo $DISTRO_PKGS \
				lazygit \
				base-devel valgrind gdb \
				taplo-cli
		)
	fi

	if $CLANG; then
		DISTRO_PKGS=$(
			echo $DISTRO_PKGS \
				clang{,-tools-extra} lldb
		)
	fi

	if $PYTHON; then
		DISTRO_PKGS=$(
			echo $DISTRO_PKGS \
				ipython python-{lsp-server,rope} ruff uv ty
		)
	fi

	if $RUST; then
		DISTRO_PKGS=$(
			echo $DISTRO_PKGS \
				base-devel openssl rustup cargo-binstall
		)
	fi

	if $DENO; then
		DISTRO_PKGS=$(
			echo $DISTRO_PKGS \
				deno
		)
	fi
	;;

debian)
	if $BASIC; then
		DISTRO_PKGS=$(
			echo $DISTRO_PKGS \
				ca-certificates \
				which less curl wget gnupg fish htop unzip gettext \
				hx ripgrep \
				tmux \
				mr vcsh git make
		)
		if [ -n "${WAYLAND_DISPLAY:-}" ]; then
			DISTRO_PKGS=$(
				echo $DISTRO_PKGS \
					wl-clipboard
			)
		elif [ -n "${DISPLAY:-}" ]; then
			DISTRO_PKGS=$(
				echo $DISTRO_PKGS \
					xclip
			)
		fi
		if [ "$TERM" = xterm-kitty ]; then
			DISTRO_PKGS=$(
				echo $DISTRO_PKGS \
					kitty-terminfo
			)
		fi
		CARGO_PKGS=$(
			echo $CARGO_PKGS \
				codebook-lsp
		)
	fi

	if $DEVEL; then
		# libtree-sitter is required to bulid helix's parsers
		DISTRO_PKGS=$(
			echo $DISTRO_PKGS \
				build-essential \
				lazygit \
				valgrind gdb \
				libtree-sitter-dev
		)
		CARGO_PKGS=$(
			echo $CARGO_PKGS \
				taplo-cli
		)
	fi

	if $CLANG; then
		DISTRO_PKGS=$(
			echo $DISTRO_PKGS \
				clang{,-tools} lldb
		)
	fi

	if $PYTHON; then
		SIDEINSTALL_UV=true
		if $PYTHON; then
			DISTRO_PKGS=$(
				echo $DISTRO_PKGS \
					ipython3 python3-{ipdb,pylsp{,-rope},numpy}
			)
			PIP_PKGS=$(
				echo $PIP_PKGS \
					ruff ty
			)
		fi
	fi

	if $RUST; then
		SIDEINSTALL_RUSTUP=true
		SIDEINSTALL_CARGO_BINSTALL=true
		DISTRO_PKGS=$(
			echo $DISTRO_PKGS \
				build-essential pkg-config libssl-dev rustup
		)
	fi

	if $DENO; then
		SIDEINSTALL_DENO=true
	fi

	;;

fedora)
	if $BASIC; then
		DISTRO_PKGS=$(
			echo $DISTRO_PKGS \
				which less curl wget gpg fish htop unzip gettext-envsubst \
				helix ripgrep \
				mr vcsh git make \
				tmux \
				dnf-plugins-core
		)
		if [ -n "${WAYLAND_DISPLAY:-}" ]; then
			DISTRO_PKGS=$(
				echo $DISTRO_PKGS \
					wl-clipboard
			)
		elif [ -n "${DISPLAY:-}" ]; then
			DISTRO_PKGS=$(
				echo $DISTRO_PKGS \
					xclip
			)
		fi
		if [ "$TERM" = xterm-kitty ]; then
			DISTRO_PKGS=$(
				echo $DISTRO_PKGS \
					kitty-terminfo
			)
		fi
		CARGO_PKGS=$(
			echo $CARGO_PKGS \
				codebook-lsp
		)
	fi

	if $DEVEL; then
		DISTRO_PKGS=$(
			echo $DISTRO_PKGS \
				lazygit \
				valgrind gdb
		)
		CARGO_PKGS=$(
			echo $CARGO_PKGS \
				taplo-cli
		)
	fi

	if $CLANG; then
		DISTRO_PKGS=$(
			echo $DISTRO_PKGS \
				clang{,-tools-extra} lldb
		)
	fi

	if $PYTHON; then
		DISTRO_PKGS=$(
			echo $DISTRO_PKGS \
				python3-{ipython,lsp-server,numpy,rope} uv
		)
		PIP_PKGS=$(
			echo $PIP_PKGS \
				ruff ty
		)
	fi

	if $RUST; then
		SIDEINSTALL_CARGO_BINSTALL=true
		DISTRO_PKGS=$(
			echo $DISTRO_PKGS \
				pkg-config openssl-devel rustup
		)
	fi

	if $DENO; then
		SIDEINSTALL_DENO=true
	fi
	;;

opensuse)
	if $BASIC; then
		DISTRO_PKGS=$(
			echo $DISTRO_PKGS \
				which less curl wget gpg fish htop unzip envsubst \
				helix{,-runtime,-fish-completion} \
				ripgrep ripgrep-fish-completion \
				tmux \
				mr vcsh git make \
				terminfo
		)
		if [ -n "${WAYLAND_DISPLAY:-}" ]; then
			DISTRO_PKGS=$(
				echo $DISTRO_PKGS \
					wl-clipboard{,-fish-completion}
			)
		elif [ -n "${DISPLAY:-}" ]; then
			DISTRO_PKGS=$(
				echo $DISTRO_PKGS \
					xclip
			)
		fi
		if [ "$TERM" = xterm-kitty ]; then
			DISTRO_PKGS=$(
				echo $DISTRO_PKGS \
					kitty-terminfo
			)
		fi
		CARGO_PKGS=$(
			echo $CARGO_PKGS \
				codebook-lsp
		)
	fi

	if $DEVEL; then
		DISTRO_PATTERNS="$DISTRO_PATTERNS devel_basis devel_C_C++"
		DISTRO_PKGS=$(
			echo $DISTRO_PKGS \
				lazygit \
				valgrind gdb \
				taplo
		)
	fi

	if $CLANG; then
		DISTRO_PKGS=$(
			echo $DISTRO_PKGS \
				clang{,-tools} lldb
		)
	fi

	if $PYTHON; then
		DISTRO_PATTERNS="$DISTRO_PATTERNS devel_python3"
		DISTRO_PKGS=$(
			echo $DISTRO_PKGS \
				python:pyver:{,-{devel,ipython,pylsp-rope,python-lsp-server,uv}}
		)
		PIP_PKGS=$(
			echo $PIP_PKGS \
				ruff ty
		)
	fi

	if $RUST; then
		SIDEINSTALL_CARGO_BINSTALL=true
		DISTRO_PKGS=$(
			echo $DISTRO_PKGS \
				rustup \
				libopenssl-devel
		)
	fi

	if $DENO; then
		DISTRO_PKGS=$(echo $DISTRO_PKGS 7zip)
		SIDEINSTALL_DENO=true
	fi
	;;
esac

# Deduplicate

DISTRO_PATTERNS=$(deduplicate $DISTRO_PATTERNS)
DISTRO_PKGS=$(deduplicate $DISTRO_PKGS)
CARGO_PKGS=$(deduplicate $CARGO_PKGS)
NPM_PKGS=$(deduplicate $NPM_PKGS)
PIP_PKGS=$(deduplicate $PIP_PKGS)

# Distro fixes

if $BASIC; then
	# Install documentation in containers
	if [ -n "${container:-}" ]; then
		case $DISTRO in
		arch)
			grep -q '^NoExtract\s*=\s*usr/share/man/\* usr/share/info/\*' /etc/pacman.conf &&
				sudo sed -i 's/^\(NoExtract\s*=\s*usr\/share\/man\/\* usr\/share\/info\/\*\)/#\1/' /etc/pacman.conf
			;;
		fedora)
			grep -q '^tsflags=nodocs' /etc/dnf/dnf.conf &&
				sudo sed -i 's/^\(tsflags=nodocs\)/# \1/' /etc/dnf/dnf.conf
			;;
		opensuse)
			grep -q '^rpm.install.excludedocs = yes' /etc/zypp/zypper.conf &&
				sudo sed -i 's/^\(rpm.install.excludedocs = yes\)/# \1/' /etc/zypp/zypper.conf
			;;
		esac

		if [ -d /mnt/shared ]; then
			echo Setting up shared volume...
			$SUDO chmod a+rwX /mnt/shared
			for dir in $HOME/{.cargo,.rustup,.cache/{pip,deno}}; do
				if [ ! -e $dir ]; then
					cache_dir=/mnt/shared/cache/$(echo $dir | sed -n 's:.*/\.\?\(.\+\)$:\1:p')
					mkdir -p $cache_dir
					mkdir -p $(dirname $dir)
					ln -s $cache_dir $dir
				fi
			done
		fi
	fi

	if [ "$DISTRO" = "fedora" ]; then
		for repo in \
			atim/lazygit; do
			$SUDO dnf copr list | grep -q $repo|| $SUDO dnf copr enable $DNF_ARGS $repo
		done
	fi
fi

# Install distro packages

if $UPGRADE; then
	echo Upgrading distro...
	case $DISTRO in
	arch)
		$SUDO pacman -Suy $PACMAN_ARGS
		if command -v paru >/dev/null; then
			paru --mode=aur -Suy $PACMAN_ARGS
		fi
		;;
	debian)
		$SUDO apt-get update && $SUDO apt-get upgrade $APT_ARGS
		;;
	fedora)
		$SUDO dnf upgrade $DNF_ARGS
		;;
	opensuse)
		$SUDO zypper refresh && $SUDO zypper dist-upgrade $ZYPPER_ARGS
		;;
	esac
fi

case $DISTRO in
arch)
	if [ -n "$DISTRO_PATTERNS" ] || [ -n "$DISTRO_PKGS" ]; then
		$SUDO pacman -S $PACMAN_ARGS $DISTRO_PATTERNS $DISTRO_PKGS
	fi
	;;
debian)
	if [ -n "$DISTRO_PATTERNS" ] || [ -n "$DISTRO_PKGS" ]; then
		$SUDO apt-get install $APT_ARGS $DISTRO_PATTERNS $DISTRO_PKGS
	fi
	;;
fedora)
	if [ -n "$DISTRO_PATTERNS" ]; then
		echo Unimplemented. Line $LINENO
		exit 1
	fi
	if [ -n "$DISTRO_PKGS" ]; then
		$SUDO dnf install $DNF_ARGS $DISTRO_PKGS
	fi
	;;
opensuse)
	if [ -n "$DISTRO_PATTERNS" ]; then
		$SUDO zypper install $ZYPPER_ARGS -t pattern $DISTRO_PATTERNS
	fi
	if [ -n "$DISTRO_PKGS" ]; then
		python_version=$(zypper info pattern:devel_python3 | grep -o 'python[0-9]\{2,5\}' | tail -n 1)
		DISTRO_PKGS=$(echo $DISTRO_PKGS | sed "s/python:pyver:/$python_version/g")
		$SUDO zypper install $ZYPPER_ARGS $DISTRO_PKGS
	fi
	;;
esac

# Dotfiles

upgrade_dotfiles() {
	command -v mr >/dev/null && [ -f $HOME/.mrconfig ] &&
		env -C $HOME mr up
	command -v fish >/dev/null && [ -f $HOME/.config/fish/Makefile ] &&
		make -C $HOME/.config/fish update
}

setup_dotfiles() {
	if [ -e $HOME/.config/vcsh/repo.d/dotfiles-mr.git ]; then
		vcsh dotfiles-mr pull
	else
		vcsh clone https://github.com/akhilman/dotfiles-mr.git
	fi

	mr_config_dir=$HOME/.config/mr/config.d
	mr_files="dotfiles-mr.vcsh dotfiles-profile.vcsh config-fish.git config-helix.git"
	if $DESKTOP; then
		mr_files="$mr_files dotfiles-desktop.vcsh"
	fi
	for f in $mr_files; do
		if [ ! -e $mr_config_dir/../available.d/$f ]; then
			echo Mr confing $f not exists
			continue
		fi
		[ -e $mr_config_dir/$f ] || env -C $mr_config_dir ln -vs ../available.d/$f ./
	done
	env -C $HOME mr up

	fish_path=$(command -v fish)
	if [ -n "$fish_path" ]; then
		make -C ~/.config/fish install
		[ $(getent passwd $(id -u) | cut -d: -f7) = $fish_path ] ||
			$SUDO usermod --shell $fish_path $(whoami)
	fi

}

if $UPGRADE; then
	echo Updating dotfiles...
	upgrade_dotfiles || true
fi

if $DOTFILES; then
	echo Setting up dotfiles
	setup_dotfiles
fi

# Flatpak

if $UPGRADE && command -v flatpak >/dev/null; then
	echo Upgrading flatpaks...
	flatpak update $FLATPAK_ARGS
fi

if $FLATPAK; then
	echo Setting up flatpak repos...
	flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
	flatpak remote-add --if-not-exists gnome-nightly https://nightly.gnome.org/gnome-nightly.flatpakrepo
fi

# Kitten

KITTEN_INSTALL_PATH="/usr/local/bin/kitten"

is_kitten_upgradable() {
	local kitten_version kitty_version

	kitten_version=$(kitten --version | awk '{print $2}')
	kitty_version=$(kitten query-terminal version | awk '/^version:/ {print $2}')

	! version_ge $kitty_version $kitten_version
}

install_kitten() {
	case "$(uname -s):$(uname -m)" in
	Linux:x86_64)
		asset="kitten-linux-amd64"
		;;
	Linux:aarch64)
		asset="kitten-linux-arm64"
		;;
	Darwin:x86_64)
		asset="kitten-macos-amd64"
		;;
	Darwin:arm64)
		asset="kitten-macos-arm64"
		;;
	*)
		echo "Unsupported platform: $(uname -s) $(uname -m)" >&2
		return 1
		;;
	esac

	curl -fL \
		"https://github.com/kovidgoyal/kitty/releases/latest/download/$asset" \
		-o "/tmp/$asset" &&
		chmod +x "/tmp/$asset" &&
		$SUDO chown root: /tmp/$asset &&
		$SUDO mv /tmp/$asset $KITTEN_INSTALL_PATH
}

if $UPGRADE &&
	[ -n "${KITTY_WINDOW_ID:-}" ] &&
	[ "$(command -v kitten)" = "$KITTEN_INSTALL_PATH" ] &&
	is_kitten_upgradable; then
	echo Updating kitten...
	$SUDO $KITTEN_INSTALL_PATH update-self
fi

if $BASIC &&
	[ -n "${KITTY_WINDOW_ID:-}" ] &&
	! command -v kitten >/dev/null; then
	echo Installing kitten...
	install_kitten
fi

# Rust

if $UPGRADE; then
	if command -v rustup >/dev/null; then
		echo Upgrading Rustup...
		rustup update
	fi

	if command -v cargo-install-update >/dev/null; then
		echo Upgrading Rust tools...
		cargo-install-update install-update --all --locked
	fi
fi

if $RUST; then
	if $YES; then
		installer_args="-y"
	else
		installer_args=""
	fi

	if $SIDEINSTALL_RUSTUP; then
		if ! command -v rustup >/dev/null; then
			echo Installing Rustup...
			curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
				sh -s - $installer_args
			. "$HOME/.cargo/env"
		fi
	fi

	if [ "$DISTRO" == "fedora" ] &&
		command -v rustup-init >/dev/null &&
		! command -v cargo >/dev/null; then
		rustup-init $installer_args
		. $HOME/.cargo/env
	fi

	if command -v rustup >/dev/null; then
		rustup default stable
		if $DEVEL; then
			rustup component add rust-analyzer
		fi
	fi

	if ! echo "$PATH" | tr ':' '\n' | grep -q "$HOME/.cargo/bin"; then
		export PATH=$HOME/.cargo/bin:$PATH
	fi

	if $SIDEINSTALL_CARGO_BINSTALL; then
		if ! command -v cargo-binstall >/dev/null; then
			echo Installing cargo-binstall...
			curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash
		fi
	fi

	if [ -n "$CARGO_PKGS" ] && command -v cargo >/dev/null; then
		# Installing Rust tools
		if command -v cargo-binstall >/dev/null; then
			cargo binstall --locked $installer_args $CARGO_PKGS
		else
			cargo install --locked $CARGO_PKGS
		fi
	fi
fi

# Deno

if $UPGRADE && command -v deno >/dev/null; then
	if test -w $(command -v deno); then
		echo Upgrading Deno...
		deno upgrade
	fi
	echo Upgrading Deno tools...
	for pkg_file in $HOME/.deno/bin/.*/deno.json; do
		pkg_dir=$(dirname $pkg_file)
		pkg_name=$(basename $pkg_dir)
		pkg_name=${pkg_name#.}
		echo Upgrading $pkg_name...
		env -C $pkg_dir deno update
	done
fi

if $DENO; then
	if $YES; then
		installer_args="-y"
	else
		installer_args=""
	fi
	if $SIDEINSTALL_DENO; then
		if ! command -v deno >/dev/null; then
			echo Installing Deno...
			curl -fsSL https://deno.land/install.sh |
				sh -s - $installer_args
			. $HOME/.deno/env
		fi
	fi

	if [ -n "$NPM_PKGS" ]; then
		echo Installing Deno tools...
		echo Unimplemented. Line $LINENO
		exit 1
	fi
fi

# Python

if $UPGRADE && command -v uv >/dev/null; then
	if test -w $(command -v uv); then
		echo Upgrading UV...
		uv self update
	fi
	echo Upgrading Python tools...
	uv tool upgrade --all
fi

if $PYTHON; then
	if $SIDEINSTALL_UV; then
		if ! command -v uv &>/dev/null; then
			echo Installing UV...
			curl -LsSf https://astral.sh/uv/install.sh | sh
			. $HOME/.local/bin/env
		fi
	fi

	if [ -n "$PIP_PKGS" ]; then
		echo Installing Python tools...
		for pkg in $PIP_PKGS; do
			uv tool install $pkg
		done
	fi
fi

setup_environment_d() {
	env_dir=$HOME/.config/environment.d
	env_files=90-path-home-bin.conf
	[ -d $HOME/.cargo/bin ] &&
		command -v cargo >/dev/null &&
		env_files="$env_files 70-path-cargo.conf"
	[ -d $HOME/.deno/bin ] &&
		command -v deno >/dev/null &&
		env_files="$env_files 70-path-deno.conf"
	$DESKTOP && env_files="$env_files 50-pass.conf 50-gopass.conf 50-desktop-theme.conf 80-ssh-askpass.conf"
	[ -S $XDG_RUNTIME_DIR/gcr/ssh ] && env_files="$env_files 80-gcr-ssh-agent.conf"
	for f in $env_files; do
		[ -e $env_dir/$f ] || env -C $env_dir ln -vs available/$f $f
	done

	editor_env_file=$env_dir/80-editor.conf
	if command -v helix >/dev/null; then
		echo EDITOR="helix" | tee $editor_env_file
	elif command -v hx >/dev/null; then
		echo EDITOR="hx" | tee $editor_env_file
	elif command -v nvim >/dev/null; then
		echo EDITOR="nvim" | tee $editor_env_file
	elif command -v vim >/dev/null; then
		echo EDITOR="vim" | tee $editor_env_file
	elif command -v nano >/dev/null; then
		echo EDITOR="nano" | tee $editor_env_file
	fi
}

# Environment.d

if $DOTFILES; then
	echo Setting up environment.d
	setup_environment_d
fi

# Helix grammars

if [ "$DISTRO" = debian ] && ($DEVEL || $UPGRADE) &&
	[ -d $HOME/.config/helix ] &&
	command -v hx >/dev/null &&
	command -v git >/dev/null && command -v c++ >/dev/null; then
	# Both fetch and build fails on some of the grammars,
	# so we just ignore faults.
	echo Setting up tree-sitter grammars for Helix
	env --unset=SSH_AUTH_SOCK --unset=SSH_ASKPASS GIT_TERMINAL_PROMPT=0 hx --grammar fetch || true
	hx --grammar build || true
fi
