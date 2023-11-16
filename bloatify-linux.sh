#!/bin/sh

# set -x

SUDO=sudo

DESKTOP=false
DEVEL=false
RUST=false

while [ $# -gt 0 ]; do
	case $1 in
		-D|--desktop)
			DESKTOP=true;;
		-d|--devel)
			DEVEL=true;;
		-r|--rust)
			RUST=true;;
		-h|--help)
			echo "Usage:"
			echo "	$(basename $0) --desktop --devel --rust"
			exit 0;;
		*)
			echo Unknown argument: \`$1\`
			exit 1;;
	esac
	shift
done

# Basic

bootstrap_basic_arch() {
	$SUDO pacman --noconfirm -S --needed \
		python which less curl wget gnupg fish vim htop \
		mr vcsh git make \
		|| exit $?
}

bootstrap_basic_debian() {
	$SUDO apt install -y \
		which less curl wget gpg fish vim htop \
		mr vcsh git make \
		|| exit $?
}

bootstrap_basic_fedora() {
	$SUDO dnf install -y \
		which less curl wget gpg fish vim htop \
		mr vcsh git make \
		dnf-plugins-core \
		|| exit $?
}

bootstrap_basic_opensuse() {
	$SUDO zypper install -y --force-resolution \
		which less curl wget gpg fish vim htop \
		mr vcsh git make \
		|| exit $?
}

# Devel

bootstrap_devel_arch() {
	$SUDO pacman --noconfirm -S --needed \
		lazygit \
		neovim ripgrep \
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
	# 	$SUDO apt update || exit $?
	# 	$SUDO apt install -y makedeb || exit $?
	#
	# 	tmpdir=/tmp/makedeb
	# 	[ -d $tmpdir/mist ] || git clone 'https://mpr.makedeb.org/mist' $tmpdir/mist
	# 	( cd $tmpdir/mist && makedeb -si -H 'MPR-Mackage: yes' )
	#
	# 	mist update
	# fi
}

bootstrap_devel_fedora() {
	$SUDO dnf copr enable -y yorickpeterse/lua-language-server || exit $?
	$SUDO dnf copr enable -y atim/lazygit || exit $?
	$SUDO dnf install -y \
		lazygit \
		neovim ripgrep \
		valgrind gdb lldb clang{,-tools-extra}  \
		python3-{ipython,ipdb,numpy,isort,lsp-{server,black}} \
		lua lua-language-server \
		|| exit $?
}

bootstrap_devel_opensuse() {
	$SUDO zypper install -y --force-resolution -t pattern \
		devel_basis devel_C_C++ devel_python3 \
		|| exit $?
	$SUDO zypper install -y --force-resolution \
		lazygit \
		neovim ripgrep ripgrep-fish-completion \
		valgrind gdb lldb clang{,-tools} \
		deno \
		python311{,-{devel,python-lsp-{server,black},pylsp-rope,isort,pylint,ipdb,ipython}} \
		lua{54,51}{,-{devel,luarocks}} lua-language-server \
		|| exit $?
}

# Rust

setup_cargo() {
	cargo install cargo-{edit,criterion,tree,update,outdated} || exit $?
}

setup_rustup() {
	rustup default stable || exit $?
	rustup component add rust-analyzer
}

bootstrap_rust_arch() {
	$SUDO pacman --noconfirm -S --needed \
		base-devel openssl rustup \
		|| exit $?
	setup_rustup
	setup_cargo
}

bootstrap_rust_debian() {
	echo Unimplemented
}

bootstrap_rust_fedora() {
	$SUDO dnf install -y \
		cargo rust-analyzer clippy rustfmt\
		openssl-devel \
		|| exit $?
	setup_cargo
}

bootstrap_rust_opensuse() {
	$SUDO zypper install -y --force-resolution \
		rustup \
		libopenssl-devel \
		|| exit $?
	setup_rustup
	setup_cargo
}

# Dot files

setup_dotfiles() {
	[ -e $HOME/.config/vcsh/repo.d/dotfiles-mr.git ] \
		|| vcsh clone https://github.com/akhilman/dotfiles-mr.git || exit $?

	mr_config_dir=$HOME/.config/mr/config.d
	mr_files="dotfiles-mr.vcsh dotfiles-profile.vcsh config-nvim.git"
	for f in $mr_files; do
		if [ ! -e $mr_config_dir/../available.d/$f ]; then
			echo Mr confing $f not exists
		fi
		[ -e $mr_config_dir/$f ] || env -C $mr_config_dir ln -vs ../available.d/$f ./ || exit $?
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
	$DESKTOP && env_files="$env_files 50-pass.conf 50-qt5-style-gnome.conf 50-qt5-style-sway.conf 80-ssh-askpass.conf"
	for f in $env_files; do
		[ -e $env_dir/$f ] || env -C $env_dir ln -vs available/$f $f
	done

	editor_env_file=$env_dir/80-editor.conf
	if command -v nvim; then
		echo EDITOR=$(command -v nvim) | tee $editor_env_file
	elif command -v vim; then
		echo EDITOR=$(command -v vim) | tee $editor_env_file
	fi

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
}

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

if [ -n "$container" -a -d /mnt/shared ]; then
	echo Setting up shared volume
	setup_shared
fi

echo Setting up basic tools
bootstrap_basic_$DISTRO

if $DEVEL; then
	echo Setting up development tools
	bootstrap_devel_$DISTRO
fi

if $RUST; then
	echo Setting up rust
	bootstrap_rust_$DISTRO
fi

echo Setting up dotfiles
setup_dotfiles

