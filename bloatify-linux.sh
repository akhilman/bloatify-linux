#!/bin/sh

# set -x

SUDO=sudo

BASIC=false
DENO=false
DESKTOP=false
DEVEL=false
DOTFILES=false
FLATPAK=false
RUST=false
UPGRADE=false
YES=false

while [ $# -gt 0 ]; do
	case $1 in
		-b|--basic) # install basic tools (basic, dotfiles)
			DOTFILES=true
			BASIC=true;;
		-D|--desktop) # install desktop relaited stuff (basic, desktop, dotfiles, flatpack)
			DOTFILES=true
			BASIC=true
			FLATPAK=true
			DESKTOP=true;;
		-d|--devel) # install development tools (basic, devel, deno, dotfiles)
			DOTFILES=true
			BASIC=true
			DENO=true
			DEVEL=true;;
		-n|--deno) # install Deno and tools running with Deno
			DENO=true;;
		-r|--rust) # install Rust
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

XDG_CONFIG_DIR=${XDG_CONFIG_DIR:-$HOME/.config}
XDG_CACHE_DIR=${XDG_CACHE_DIR:-$HOME/.cache}

PACMAN_ARGS="--needed"
APT_ARGS=""
DNF_ARGS=""
ZYPPER_ARGS=""

if $YES; then
	PACMAN_ARGS="$PACMAN_ARGS --noconfirm"
	APT_ARGS="$APT_ARGS -y"
	DNF_ARGS="$DNF_ARGS -y"
	ZYPPER_ARGS="$ZYPPER_ARGS -y --force-resolution"
fi

# Upgrade

upgrade_arch() {
	$SUDO pacman -Suy $PACMAN_ARGS || exit $?
}

upgrade_debian() {
	$SUDO apt-get upgrade $APT_ARGS || exit $?
}

upgrade_fedora() {
	$SUDO dnf upgrate $DNF_ARGS || exit $?
}

upgrade_opensuse() {
	$SUDO zypper upgrade $ZYPPER_ARGS || exit $?
}

# Basic

bootstrap_basic_arch() {
	pkgs=$(echo \
		python which less curl wget gnupg fish htop \
		vim helix ripgrep \
		tmux powerline \
		mr vcsh git make \
		)
	if [ -n "$WAYLAND_DISPLAY" ]; then
		pkgs=$(echo $pkgs \
			wl-clipboard \
			)
	fi
	$SUDO pacman -S $PACMAN_ARGS $pkgs || exit $?
}

bootstrap_basic_debian() {
	pkgs=$(echo \
		which less curl wget gpg fish vim htop \
		tmux powerline \
		mr vcsh git make \
		)
	if [ -n "$WAYLAND_DISPLAY" ]; then
		pkgs=$(echo $pkgs \
			wl-clipboard \
			)
	fi
	$SUDO apt-get install $APT_ARGS $pkgs || exit $?
}

bootstrap_basic_fedora() {
	pkgs=$(echo \
		which less curl wget gpg fish htop \
		vim helix ripgrep \
		mr vcsh git make \
		tmux tmux-powerline \
		dnf-plugins-core \
		)
	if [ -n "$WAYLAND_DISPLAY" ]; then
		pkgs=$(echo $pkgs \
			wl-clipboard \
			)
	fi
	$SUDO dnf install $DNF_ARGS $pkgs || exit $?
}

bootstrap_basic_opensuse() {
	pkgs=$(echo \
		which less curl wget gpg fish htop \
		vim vim-data \
		helix{,-runtime,-fish-completion} \
		ripgrep ripgrep-fish-completion \
		tmux tmux-powerline terminfo \
		mr vcsh git make \
		)
	if [ -n "$WAYLAND_DISPLAY" ]; then
		pkgs=$(echo $pkgs \
			wl-clipboard{,-fish-completion} \
			)
	fi
	$SUDO zypper install $ZYPPER_ARGS $pkgs || exit $?
}

# Devel

bootstrap_devel_arch() {
	$SUDO pacman -S $PACMAN_ARGS \
		lazygit \
		base-devel valgrind gdb lldb clang{,-tools-extra} \
		python-{ipdb,numpy,isort,lsp-{server,black}} ipython \
		lua lua-language-server \
		|| exit $?
}

bootstrap_devel_debian() {
	echo Unimplemented

	# if $thirdparty; then
	# 	curl -L 'https://proget.makedeb.org/debian-feeds/makedeb.pub' | gpg --dearmor | $SUDO tee /usr/share/keyrings/makedeb-archive-keyring.gpg 1> /dev/null || exit $?
	# 	echo 'deb [signed-by=/usr/share/keyrings/makedeb-archive-keyring.gpg arch=all] https://proget.makedeb.org/ makedeb main' | $SUDO tee /etc/apt/sources.list.d/makedeb.list || exit $?
	#
	# 	$SUDO apt-get update || exit $?
	# 	$SUDO apt-get install $APT_ARGS makedeb || exit $?
	#
	# 	tmpdir=/tmp/makedeb
	# 	[ -d $tmpdir/mist ] || git clone 'https://mpr.makedeb.org/mist' $tmpdir/mist
	# 	( cd $tmpdir/mist && makedeb -si -H 'MPR-Mackage: yes' )
	#
	# 	mist update
	# fi
}

bootstrap_devel_fedora() {
	$SUDO dnf copr enable $DNF_ARGS yorickpeterse/lua-language-server || exit $?
	$SUDO dnf copr enable $DNF_ARGS atim/lazygit || exit $?
	$SUDO dnf install $DNF_ARGS \
		lazygit \
		valgrind gdb lldb clang{,-tools-extra}  \
		python3-{ipython,ipdb,numpy,isort,lsp-{server,black}} \
		lua lua-language-server \
		|| exit $?
}

bootstrap_devel_opensuse() {
	$SUDO zypper install $ZYPPER_ARGS -t pattern \
		devel_basis devel_C_C++ devel_python3 \
		|| exit $?
	$SUDO zypper install $ZYPPER_ARGS \
		lazygit \
		valgrind gdb lldb clang{,-tools} \
		python311{,-{devel,python-lsp-{server,black},pylsp-rope,isort,pylint,ipdb,ipython}} \
		lua{54,51}{,-{devel,luarocks}} lua-language-server \
		|| exit $?
}

# Flatpak

setup_flatpak() {
	echo Flatpak support not yet done
}

bootstrap_flatpak_arch() {
	setup_flatpak
}

bootstrap_flatpak_debian() {
	setup_flatpak
}

bootstrap_flatpak_fedora() {
	setup_flatpak
}

bootstrap_flatpak_opensuse() {
	setup_flatpak
}

upgrade_flatpak() {
	command -v flatpak > /dev/null || return
	FLATPAK_ARGS=""
	if $YES; then
		FLATPAK_ARGS="$FLATPAK_ARGS --assumeyes --noninteracpive"
	fi
	flatpak update $FLATPAK_ARGS
}

# Rust

upgrade_rust() {
	command -v rustup > /dev/null \
		&& ( rustup update || exit $? )
	command -v cargo-install-update > /dev/null \
		&& ( cargo-install-update install-update --all || exit $? )
}

setup_cargo() {
	cargo install cargo-{edit,criterion,tree,update,outdated} || exit $?
}

setup_rustup() {
	rustup default stable || exit $?
	rustup component add rust-analyzer
}

bootstrap_rust_arch() {
	$SUDO pacman -S $PACMAN_ARGS \
		base-devel openssl rustup \
		|| exit $?
	setup_rustup
	setup_cargo
}

bootstrap_rust_debian() {
	echo Unimplemented
}

bootstrap_rust_fedora() {
	$SUDO dnf install $DNF_ARGS \
		cargo rust-analyzer clippy rustfmt\
		openssl-devel \
		|| exit $?
	setup_cargo
}

bootstrap_rust_opensuse() {
	$SUDO zypper install $ZYPPER_ARGS \
		rustup \
		libopenssl-devel \
		|| exit $?
	setup_rustup
	setup_cargo
}

# Deno

CSPELL_DICTS="rust ru_ru"

install_deno_tools() {
	dict_packages=
	for dict in $CSPELL_DICTS; do
		dict_packages="$dict_packages npm:@cspell/dict-$dict"
	done

	deno cache $1 \
		npm:cspell \
		npm:diagnostic-languageserver \
		$dict_packages \
		|| exit $?

	deno install \
		--force --allow-read --allow-env --allow-write=$XDG_CONFIG_DIR/configstore \
		--name=cspell npm:cspell \
		|| exit $?
	deno install \
		--force --allow-read --allow-env --allow-sys=uid --allow-run \
		--name=diagnostic-languageserver npm:diagnostic-languageserver \
		|| exit $?

	# for dict in $BUILTIN_CSPELL_DICTS $CSPELL_DICTS; do
	# 	~/.deno/bin/cspell link add $(ls $XDG_CACHE_DIR/deno/npm/registry.npmjs.org/@cspell/dict-$dict/*/cspell-ext.json | tail -n 1)
	# done
}

upgrade_deno() {
	command -v deno > /dev/null \
	&& install_deno_tools --reload
}

bootstrap_deno_arch() {
	$SUDO pacman -S $PACMAN_ARGS deno \
		|| exit $?
	install_deno_tools
}

bootstrap_deno_debian() {
	echo Unsupported
}

bootstrap_deno_fedora() {
	echo Unsupported
}

bootstrap_deno_opensuse() {
	$SUDO zypper install $ZYPPER_ARGS \
		deno \
		|| exit $?
	install_deno_tools
}

# Dot files

setup_dotfiles() {
	[ -e $HOME/.config/vcsh/repo.d/dotfiles-mr.git ] \
		|| vcsh clone https://github.com/akhilman/dotfiles-mr.git || exit $?

	mr_config_dir=$HOME/.config/mr/config.d
	mr_files="dotfiles-mr.vcsh dotfiles-profile.vcsh config-helix.git config-nvim.git"
	for f in $mr_files; do
		if [ ! -e $mr_config_dir/../available.d/$f ]; then
			echo Mr confing $f not exists
			continue
		fi
		f_git=$(echo $f | sed -e 's/\.vcsh$/.ssh.vcsh/' -e 's/\.git$/.ssh.git/')
		[ -e $mr_config_dir/$f ] || [ -e $mr_config_dir/$f_git ] || env -C $mr_config_dir ln -vs ../available.d/$f ./ || exit $?
	done
 	env -C $HOME mr up || exit $?

	if command -v fish > /dev/null; then
		make -C ~/.config/fish install || exit $?
		$SUDO usermod --shell $(command -v fish) $(whoami) || exit $?
	fi

	env_dir=$HOME/.config/environment.d
	env_files=90-path-home-bin.conf
	[ -d $HOME/.cargo/bin ] \
		&& command -v cargo > /dev/null \
		&& env_files="$env_files 70-path-cargo.conf"
	[ -d $HOME/.deno/bin ] \
		&& command -v deno > /dev/null \
		&& env_files="$env_files 70-path-deno.conf"
	$DESKTOP && env_files="$env_files 50-pass.conf 50-qt5-style-gnome.conf 80-ssh-askpass.conf"
	for f in $env_files; do
		[ -e $env_dir/$f ] || env -C $env_dir ln -vs available/$f $f
	done

	editor_env_file=$env_dir/80-editor.conf
	if command -v helix > /dev/null; then
		echo EDITOR=$(command -v helix) | tee $editor_env_file
	elif command -v nvim > /dev/null; then
		echo EDITOR=$(command -v nvim) | tee $editor_env_file
	elif command -v vim > /dev/null; then
		echo EDITOR=$(command -v vim) | tee $editor_env_file
	fi

	if [ x$CONTAINER_MANAGER = xtinkerbox ]; then
		[ -e $HOME/.profile ] || echo \#!/bin/sh > $HOME/.profile
		if ! grep -q /.config/environment.d/ $HOME/.profile; then
			cat >> $HOME/.profile <<EOF

for f in \$HOME/.config/environment.d/*.conf; do
	while read -r line; do
		echo "\$line" | grep -q '^\w*=' || continue
		eval export "\$line"
	done < \$f
done
EOF
		fi
	fi
}

upgrade_dotfiles() {
	command -v mr > /dev/null && [ -f $HOME/.mrconfig ] \
		&& env -C $HOME mr up || exit $?
	command -v fish > /dev/null && [ -f $HOME/.config/fish/Makefile ] \
		&& make -C $HOME/.config/fish update
}

# Shared volume

setup_shared() {
	$SUDO chmod a+rwX /mnt/shared
	for dir in $HOME/{.cargo,.rustup,.cache/{pip,deno}}; do
		if [ ! -e $dir ]; then 
			cache_dir=/mnt/shared/cache/$(echo $dir | sed -n 's:.*/\.\?\(.\+\)$:\1:p')
			mkdir -p $cache_dir
			mkdir -p $(dirname $dir)
			ln -s $cache_dir $dir 
		fi
	done
}

echo -n "Package manager: "
# if command -v apk; then
# 	DISTRO=alpine
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

if $UPGRADE; then
	echo Upgrading
	upgrade_$DISTRO
	upgrade_flatpak
	upgrade_rust
	upgrade_deno
	upgrade_dotfiles
fi

if $BASIC; then
	echo Setting up basic tools
	bootstrap_basic_$DISTRO

	if [ -n "$container" -a -d /mnt/shared ]; then
		echo Setting up shared volume
		setup_shared
	fi
fi

if $FLATPAK; then
	echo Setting up flatpak
	bootstrap_flatpak_$DISTRO
fi

if $DEVEL; then
	echo Setting up development tools
	bootstrap_devel_$DISTRO
fi

if $RUST; then
	echo Setting up Rust
	bootstrap_rust_$DISTRO
fi

if $DENO; then
	echo Setting up Deno
	bootstrap_deno_$DISTRO
fi

if $DOTFILES; then
	echo Setting up dotfiles
	setup_dotfiles
fi

