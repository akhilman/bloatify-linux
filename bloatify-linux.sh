#!/bin/bash

# set -x

if [ $(id -u) -eq 0 ]; then
	echo This script should not be run by root.
	exit 1
fi

SUDO=sudo

BASIC=false
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
	case $1 in
		-b|--basic) # install basic tools (basic, dotfiles)
			BASIC=true;;
		-D|--desktop) # install desktop relaited stuff (basic, desktop, dotfiles, flatpack)
			DESKTOP=true;;
		-d|--devel) # install development tools (basic, devel, deno, dotfiles)
			DEVEL=true;;
		-n|--deno) # install Deno tools
			DENO=true;;
		-p|--python) # Install Python tools
			PYTHON=true;;
		-r|--rust) # install Rust tools
			RUST=true;;
		-t|--dotfiles) # install dotfiles
			DOTFILES=true;;
		-u|--upgrade) # upgrade everything
			UPGRADE=true;;
		-y|--yes) # do not ask any questions
			YES=true;;
		-h|--help) # show help
			echo "Usage:"
			echo "	$(basename $0) [options]"
			echo "Options:"
			cat $0 | sed -n 's/^\s*\(-\w\)|\(--\w\+\))\s\+#\s\+\(.*\)$/\t\1, \2\t\3/p'
			exit 0;;
		*)
			echo Unknown argument: \`$1\`
			exit 1;;
	esac
	shift
done

if $DESKTOP; then
	BASIC=true
	DOTFILES=true
fi

if $DOTFILES || $DEVEL || $DENO || $PYTHON || $RUST; then
	BASIC=true
fi

echo -n "Package manager: "
if command -v apt-get; then
	DISTRO=debian
elif command -v dnf; then
	DISTRO=fedora
elif command -v pacman; then
	DISTRO=arch
elif command -v zypper; then
	DISTRO=opensuse
else
	echo ERROR: Unsupported distro!
	exit 1
fi

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
	echo $(echo $@| tr '\n' ' ' | sort -u )
}

BASIC_CARGO_PKGS=""
BASIC_DISTRO_PKGS=""
BASIC_DISTRO_PATTERNS=""
BASIC_NPM_PKGS=""
BASIC_PIP_PKGS=""
DENO_CARGO_PKGS=""
DENO_DISTRO_PKGS=""
DENO_DISTRO_PATTERNS=""
DENO_NPM_PKGS=""
DENO_PIP_PKGS=""
DESKTOP_CARGO_PKGS=""
DESKTOP_DISTRO_PKGS=""
DESKTOP_DISTRO_PATTERNS=""
DESKTOP_NPM_PKGS=""
DESKTOP_PIP_PKGS=""
DEVEL_CARGO_PKGS=""
DEVEL_DISTRO_PKGS=""
DEVEL_DISTRO_PATTERNS=""
DEVEL_NPM_PKGS=""
DEVEL_PIP_PKGS=""
FLATPAK_DISTRO_PKGS="flatpak"
PYTHON_CARGO_PKGS=""
PYTHON_DISTRO_PKGS=""
PYTHON_DISTRO_PATTERNS=""
PYTHON_NPM_PKGS=""
PYTHON_PIP_PKGS=""
RUST_CARGO_PKGS=$(echo cargo-{cache,criterion,edit,machete,outdated,tree,update})
RUST_DISTRO_PKGS=""
RUST_DISTRO_PATTERNS=""
RUST_NPM_PKGS=""
RUST_PIP_PKGS=""

SIDEINSTALL_DENO=false
SIDEINSTALL_RUSTUP=false
SIDEINSTALL_UV=false

case $DISTRO in
	arch)
		BASIC_DISTRO_PKGS=$(echo \
			which less curl wget gnupg fish htop unzip gettext \
			helix ripgrep codebook-lsp \
			tmux \
			mr vcsh git make \
			)
		if [ -n "$WAYLAND_DISPLAY" ]; then
			BASIC_DISTRO_PKGS=$(echo $BASIC_DISTRO_PKGS \
				wl-clipboard \
				)
		fi
		if [ "$TERM" = xterm-kitty ]; then
			BASIC_DISTRO_PKGS=$(echo $BASIC_DISTRO_PKGS \
				kitty-terminfo \
				)
		fi

		DEVEL_DISTRO_PKGS=$(echo \
			lazygit \
			base-devel valgrind gdb lldb clang{,-tools-extra} \
			taplo-cli \
		)

		PYTHON_DISTRO_PKGS=$(echo \
			ipython ruff uv \
		)

		RUST_DISTRO_PKGS=$(echo \
			base-devel openssl rustup \
		)

		DENO_DISTRO_PKGS=$(echo \
			deno \
		)
	;;

	debian)
		BASIC_DISTRO_PKGS=$(echo \
			ca-certificates \
			which less curl wget gnupg fish htop unzip gettext \
			hx ripgrep \
			tmux \
			mr vcsh git make \
			)
		if [ -n "$WAYLAND_DISPLAY" ]; then
			BASIC_DISTRO_PKGS=$(echo $BASIC_DISTRO_PKGS \
				wl-clipboard \
				)
		fi
		if [ "$TERM" = xterm-kitty ]; then
			BASIC_DISTRO_PKGS=$(echo $BASIC_DISTRO_PKGS \
				kitty-terminfo \
				)
		fi
		BASIC_CARGO_PKGS=$(echo \
			codebook-lsp \
		)

		DEVEL_DISTRO_PKGS=$(echo \
	    build-essential \
	    lazygit \
	    valgrind gdb lldb clang clang-tools \
		)

		SIDEINSTALL_UV=true
		PYTHON_DISTRO_PKGS=$(echo \
			ipython3 python3-{ipdb,isort,pylsp,numpy} \
		)
		PYTHON_PIP_PKGS=$(echo \
			ruff ty \
		)

		SIDEINSTALL_RUSTUP=true
		RUST_DISTRO_PKGS=$(echo \
			pkg-config libssl-dev rustup \
		)

		SIDEINSTALL_DENO=true
	
	;;

	fedora)
		BASIC_DISTRO_PKGS=$(echo \
			which less curl wget gpg fish htop unzip gettext-envsubst \
			helix ripgrep \
			mr vcsh git make \
			tmux \
			dnf-plugins-core \
			)
		if [ -n "$WAYLAND_DISPLAY" ]; then
			BASIC_DISTRO_PKGS=$(echo $BASIC_DISTRO_PKGS \
				wl-clipboard \
				)
		fi
		if [ "$TERM" = xterm-kitty ]; then
			BASIC_DISTRO_PKGS=$(echo $BASIC_DISTRO_PKGS \
				kitty-terminfo \
				)
		fi
		BASIC_CARGO_PKGS=$(echo \
			codebook-lsp \
		)

		DEVEL_DISTRO_PKGS=$(echo \
			lazygit \
			valgrind gdb lldb clang{,-tools-extra}  \
		)

		PYTHON_DISTRO_PKGS=$(echo \
			python3-{ipython,isort,lsp-server,numpy} ruff uv \
		)

		RUST_DISTRO_PKGS=$(echo \
			pkg-config openssl-devel rustup \
		)

		SIDEINSTALL_DENO=true
	;;

	opensuse)
		BASIC_DISTRO_PKGS=$(echo $BASIC_DISTRO_PKGS \
			which less curl wget gpg fish htop unzip envsubst \
			helix{,-runtime,-fish-completion} \
			ripgrep ripgrep-fish-completion \
			tmux \
			mr vcsh git make \
			terminfo \
			)
		if [ -n "$WAYLAND_DISPLAY" ]; then
			BASIC_DISTRO_PKGS=$(echo $BASIC_DISTRO_PKGS \
				wl-clipboard{,-fish-completion} \
				)
		fi
		if [ "$TERM" = xterm-kitty ]; then
			BASIC_DISTRO_PKGS=$(echo $BASIC_DISTRO_PKGS \
				kitty-terminfo \
				)
		fi
		BASIC_CARGO_PKGS=$(echo \
			codebook-lsp \
		)

		DEVEL_DISTRO_PATTERNS="devel_basis devel_C_C++"
		DEVEL_DISTRO_PKGS=$(echo \
			lazygit \
			valgrind gdb lldb clang{,-tools} \
			taplo \
		)

		PYTHON_DISTRO_PATTERNS="devel_python3"
		PYTHON_DISTRO_PKGS=$(echo \
			python:pyver:{,-{devel,ipython,pylsp-rope,python-lsp-server,ruff,uv}} \
		)
		PYTHON_PIP_PKGS=$(echo \
			ty \
		)

		RUST_DISTRO_PKGS=$(echo \
			rustup \
			libopenssl-devel \
		)

		DENO_DISTRO_PKGS=$(echo $DENO_DISTRO_PKGS 7zip)
		SIDEINSTALL_DENO=true
	;;
esac

# Fix configuration

fix_system_config() {
	# Install documentation in containers
	if [ -n "$container" ]; then
		case $DISTRO in
			arch)
				grep -q '^NoExtract\s*=\s*usr/share/man/\* usr/share/info/\*' /etc/pacman.conf \
					&& sudo sed -i 's/^\(NoExtract\s*=\s*usr\/share\/man\/\* usr\/share\/info\/\*\)/#\1/' /etc/pacman.conf ;;
			fedora)
				grep -q '^tsflags=nodocs' /etc/dnf/dnf.conf \
					&& sudo sed -i 's/^\(tsflags=nodocs\)/# \1/' /etc/dnf/dnf.conf ;;
			opensuse)
				grep -q '^rpm.install.excludedocs = yes' /etc/zypp/zypper.conf \
					&& sudo sed -i 's/^\(rpm.install.excludedocs = yes\)/# \1/' /etc/zypp/zypper.conf ;;
		esac
	fi

	if [ "$DISTRO" = "fedora" ]; then
		$SUDO dnf copr enable $DNF_ARGS atim/lazygit || exit $?
	fi
}

# Dot files

setup_dotfiles() {
	if [ -e $HOME/.config/vcsh/repo.d/dotfiles-mr.git ]; then
		vcsh dotfiles-mr pull || exit $?
	else
		vcsh clone https://codeberg.org/AkhIL/dotfiles-mr.git || exit $?
	fi

	mr_config_dir=$HOME/.config/mr/config.d
	mr_files="dotfiles-mr.vcsh dotfiles-profile.vcsh config-fish.git config-helix.git config-efm-langserver.git"
	if $DESKTOP; then
		mr_files="$mr_files dotfiles-desktop.vcsh"
	fi
	for f in $mr_files; do
		if [ ! -e $mr_config_dir/../available.d/$f ]; then
			echo Mr confing $f not exists
			continue
		fi
		[ -e $mr_config_dir/$f ] || env -C $mr_config_dir ln -vs ../available.d/$f ./ || exit $?
	done
 	env -C $HOME mr up || exit $?

	fish_path=$(command -v fish)
	if [ -n "$fish_path" ]; then
		make -C ~/.config/fish install || exit $?
		[ $(getent passwd $(id -u) | cut -d: -f7) = $fish_path ] \
			|| $SUDO usermod --shell $fish_path $(whoami) || exit $?
	fi

	env_dir=$HOME/.config/environment.d
	env_files=90-path-home-bin.conf
	[ -d $HOME/.cargo/bin ] \
		&& command -v cargo > /dev/null \
		&& env_files="$env_files 70-path-cargo.conf"
	[ -d $HOME/.deno/bin ] \
		&& command -v deno > /dev/null \
		&& env_files="$env_files 70-path-deno.conf"
	$DESKTOP && env_files="$env_files 50-pass.conf 50-gopass.conf 50-qt5-style-gnome.conf 80-ssh-askpass.conf"
	for f in $env_files; do
		[ -e $env_dir/$f ] || env -C $env_dir ln -vs available/$f $f
	done

	editor_env_file=$env_dir/80-editor.conf
	if command -v helix > /dev/null; then
		echo EDITOR="helix" | tee $editor_env_file
	elif command -v hx > /dev/null; then
		echo EDITOR="hx" | tee $editor_env_file
	elif command -v nvim > /dev/null; then
		echo EDITOR="nvim" | tee $editor_env_file
	elif command -v vim > /dev/null; then
		echo EDITOR="vim" | tee $editor_env_file
	elif command -v nano > /dev/null; then
		echo EDITOR="nano" | tee $editor_env_file
	fi
}

upgrade_dotfiles() {
	echo Updating dotfiles...
	command -v mr > /dev/null && [ -f $HOME/.mrconfig ] \
		&& env -C $HOME mr up || exit $?
	command -v fish > /dev/null && [ -f $HOME/.config/fish/Makefile ] \
		&& make -C $HOME/.config/fish update
}

# Shared volume

setup_shared() {
	if [ -n "$container" -a -d /mnt/shared ]; then
		echo Setting up shared volume
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
}

DISTRO_PATTERNS=""
DISTRO_PKGS=""
CARGO_PKGS=""
NPM_PKGS=""
PIP_PKGS=""

if $BASIC; then
	DISTRO_PATTERNS=$(echo $DISTRO_PATTERNS $BASIC_DISTRO_PATTERNS)
	DISTRO_PKGS=$(echo $DISTRO_PKGS $BASIC_DISTRO_PKGS)
	CARGO_PKGS=$(echo $CARGO_PKGS $BASIC_CARGO_PKGS)
	NPM_PKGS=$(echo $NPM_PKGS $BASIC_NPM_PKGS)
	PIP_PKGS=$(echo $PIP_PKGS $BASIC_PIP_PKGS)
fi

if $DESKTOP; then
	DISTRO_PATTERNS=$(echo $DISTRO_PATTERNS $DESKTOP_DISTRO_PATTERNS)
	DISTRO_PKGS=$(echo $DISTRO_PKGS $DESKTOP_DISTRO_PKGS)
	CARGO_PKGS=$(echo $CARGO_PKGS $DESKTOP_CARGO_PKGS)
	NPM_PKGS=$(echo $NPM_PKGS $DESKTOP_NPM_PKGS)
	PIP_PKGS=$(echo $PIP_PKGS $DESKTOP_PIP_PKGS)
fi

if $FLATPAK; then
	DISTRO_PKGS=$(echo $DISTRO_PKGS $FLATPAK_DISTRO_PKGS)
fi

if $DEVEL; then
	DISTRO_PATTERNS=$(echo $DISTRO_PATTERNS $DEVEL_DISTRO_PATTERNS)
	DISTRO_PKGS=$(echo $DISTRO_PKGS $DEVEL_DISTRO_PKGS)
	CARGO_PKGS=$(echo $CARGO_PKGS $DEVEL_CARGO_PKGS)
	NPM_PKGS=$(echo $NPM_PKGS $DEVEL_NPM_PKGS)
	PIP_PKGS=$(echo $PIP_PKGS $DEVEL_PIP_PKGS)
fi

if $PYTHON; then
	DISTRO_PATTERNS=$(echo $DISTRO_PATTERNS $PYTHON_DISTRO_PATTERNS)
	DISTRO_PKGS=$(echo $DISTRO_PKGS $PYTHON_DISTRO_PKGS)
	CARGO_PKGS=$(echo $CARGO_PKGS $PYTHON_CARGO_PKGS)
	NPM_PKGS=$(echo $NPM_PKGS $PYTHON_NPM_PKGS)
	PIP_PKGS=$(echo $PIP_PKGS $PYTHON_PIP_PKGS)
fi

if $RUST; then
	DISTRO_PATTERNS=$(echo $DISTRO_PATTERNS $RUST_DISTRO_PATTERNS)
	DISTRO_PKGS=$(echo $DISTRO_PKGS $RUST_DISTRO_PKGS)
	CARGO_PKGS=$(echo $CARGO_PKGS $RUST_CARGO_PKGS)
	NPM_PKGS=$(echo $NPM_PKGS $RUST_NPM_PKGS)
	PIP_PKGS=$(echo $PIP_PKGS $RUST_PIP_PKGS)
fi

if $DENO; then
	DISTRO_PATTERNS=$(echo $DISTRO_PATTERNS $DENO_DISTRO_PATTERNS)
	DISTRO_PKGS=$(echo $DISTRO_PKGS $DENO_DISTRO_PKGS)
	CARGO_PKGS=$(echo $CARGO_PKGS $DENO_CARGO_PKGS)
	NPM_PKGS=$(echo $NPM_PKGS $DENO_NPM_PKGS)
	PIP_PKGS=$(echo $PIP_PKGS $DENO_PIP_PKGS)
fi

# Deduplicate

DISTRO_PATTERNS=$(deduplicate $DISTRO_PATTERNS)
DISTRO_PKGS=$(deduplicate $DISTRO_PKGS)
CARGO_PKGS=$(deduplicate $CARGO_PKGS)
NPM_PKGS=$(deduplicate $NPM_PKGS)
PIP_PKGS=$(deduplicate $PIP_PKGS)

# Distro fixes

if $BASIC; then
	fix_system_config
	setup_shared
fi

# Upgrade

if $UPGRADE; then
	echo Upgrading distro
	case $DISTRO in
		arch)
			$SUDO pacman -Suy $PACMAN_ARGS || exit $?
			if command -v paru > /dev/null; then
				paru --mode=aur -Suy $PACMAN_ARGS || exit $?
			fi ;;
		debian)
			$SUDO apt-get update && $SUDO apt-get upgrade $APT_ARGS || exit $? ;;
		fedora)
			$SUDO dnf upgrade $DNF_ARGS || exit $? ;;
		opensuse)
			$SUDO zypper refresh && $SUDO zypper dist-upgrade $ZYPPER_ARGS || exit $? ;;
	esac

	if command -v flatpak > /dev/null; then
		echo Upgrading flatpaks
		flatpak update $FLATPAK_ARGS || exit $?
	fi

	if command -v deno > /dev/null; then
		if test -w $(command -v deno); then
			echo Upgrading deno
			deno upgrade || exit $?;
		fi
		echo Upgrading deno tools
		# TODO
	fi

	if command -v uv > /dev/null; then
		echo Upgrading python tools
		if test -w $(command -v uv); then
			uv self update || exit $?
		fi
		uv tool upgrade --all || exit $?
	fi

	if command -v rustup > /dev/null; then
		echo Upgrading rustup
		rustup update || exit $?
	fi
	if command -v cargo-install-update > /dev/null; then
		echo Upgrading rust tools
		cargo-install-update install-update --all --locked || exit $?
	fi

	upgrade_dotfiles
fi

# Install distro packages

case $DISTRO in
	arch)
		if [ -n "$DISTRO_PATTERNS" ] || [ -n "$DISTRO_PKGS" ]; then
			$SUDO pacman -S $PACMAN_ARGS $DISTRO_PATTERNS $DISTRO_PKGS || exit $?
		fi
		;;
	debian)
		if [ -n "$DISTRO_PATTERNS" ] || [ -n "$DISTRO_PKGS" ]; then
			$SUDO apt-get install $APT_ARGS $DISTRO_PATTERNS $DISTRO_PKGS || exit $?
		fi
		;;
	fedora)
		if [ -n "$DISTRO_PATTERNS" ]; then
			echo Unimplemented. Line $LINENO
			exit 1
		fi
		if [ -n "$DISTRO_PKGS" ]; then
			$SUDO dnf install $DNF_ARGS $DISTRO_PKGS || exit $?
		fi
		;;
	opensuse)
		if [ -n "$DISTRO_PATTERNS" ]; then
			$SUDO zypper install $ZYPPER_ARGS -t pattern $DISTRO_PATTERNS || exit $?
		fi
		if [ -n "$DISTRO_PKGS" ]; then
			python_version=$(zypper info pattern:devel_python3 | grep -o 'python[0-9]\{2,5\}' | tail -n 1)
			DISTRO_PKGS=$(echo $DISTRO_PKGS | sed "s/python:pyver:/$python_version/g")
			$SUDO zypper install $ZYPPER_ARGS $DISTRO_PKGS || exit $?
		fi
		;;
esac

# Flatpak

if $FLATPAK; then
	echo Setting up flatpak repos
	flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || exit $?
	flatpak remote-add --if-not-exists gnome-nightly https://nightly.gnome.org/gnome-nightly.flatpakrepo || exit $?
fi

# Rust

if $RUST; then
	if $YES; then
		installer_args="-y"
	else
		installer_args=""
	fi

	if $SIDEINSTALL_RUSTUP; then
		if ! command -v rustup > /dev/null; then
			echo Installing Rustup
			curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
				| sh -s - $installer_args \
				|| exit $?
			. "$HOME/.cargo/env"
		fi
	fi

	if [ "$DISTRO" == "fedora" ] \
			&& command -v rustup-init > /dev/null \
			&& ! command -v cargo > /dev/null; then
		rustup-init $installer_args || exit $?
		. $HOME/.cargo/env
	fi

	if command -v rustup > /dev/null && command -v cargo > /dev/null; then
		rustup default stable || exit $?
	fi

	if [ -n "$CARGO_PKGS" ]; then
		# Installing Rust tools
		cargo install --locked $CARGO_PKGS || exit $?
	fi
fi

# Deno

if $DENO; then
	if $YES; then
		installer_args="-y"
	else
		installer_args=""
	fi
	if $SIDEINSTALL_DENO; then
		if ! command -v deno > /dev/null; then
			echo Installing Deno
			curl -fsSL https://deno.land/install.sh \
				| sh -s - $installer_args \
				|| exit $?
			. $HOME/.deno/env
		fi
	fi

	if [ -n "$NPM_PKGS" ]; then
		echo Installing Deno tools
		echo Unimplemented. Line $LINENO
		exit 1
	fi
fi

# Python

if $PYTHON; then
	if $SIDEINSTAL_UV; then
		if ! command -v uv &> /dev/null; then
			echo Installing UV
			curl -LsSf https://astral.sh/uv/install.sh | sh || exit $?
			. $HOME/.local/bin/env
		fi
	fi

	if [ -n "$PIP_PKGS" ]; then
		echo Installing Python tools
		for pkg in $PIP_PKGS; do
			uv tool install $pkg || exit $?
		done
	fi
fi

# Dotfiles

if $DOTFILES; then
	echo Setting up dotfiles
	setup_dotfiles
fi

