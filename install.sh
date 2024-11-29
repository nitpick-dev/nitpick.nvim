echo "installing nitpick"

os() {
	case "$OSTYPE" in
		darwin*)
			echo "macos"
		;;
		# FIXME: account for muscl
		linux*)
			echo "linux-gnu"
		;;
		*)
			echo "Unsupported: $OSTYPE"
			exit 1
		;;
	esac
}

arch() {
	case "$(uname -m)" in
		arm64)
			echo "aarch64"
		;;
		*)
			echo "$(uname -m)"
		;;
	esac
}

filename="libnitpick-$(arch)-$(os).tar.gz"

# FIXME: make this configurable
INSTALL_DIR="$HOME/.local/bin"
if ! test -d $INSTALL_DIR; then
	echo "creating $INSTALL_DIR"
	mkdir -p $INSTALL_DIR
fi

echo "downloading $filename"

# FIXME: use the editors repo
curl \
	"https://github.com/nitpick-dev/nitpick.nvim/releases/download/dev/$filename" \
	-LO

echo "installing to $INSTALL_DIR"

tar xf $filename -C $INSTALL_DIR

rm -rf $filename

echo "done"
