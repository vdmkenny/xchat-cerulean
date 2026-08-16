#!/bin/bash
. set_variables.sh

if [ "$1" = 'clean' ]; then
	rm -rf "$MO_BASE_DIR"/*
	exit
fi

# The repository used to ship a prebuilt msgfmt, a ppc/i386 binary that no
# macOS has been able to run for over a decade, so every locale silently
# failed to build. Use the one from gettext.
MSGFMT="$(command -v msgfmt || true)"
for candidate in /opt/homebrew/opt/gettext/bin/msgfmt /usr/local/opt/gettext/bin/msgfmt; do
	[ -n "$MSGFMT" ] && break
	[ -x "$candidate" ] && MSGFMT="$candidate"
done
if [ -z "$MSGFMT" ]; then
	echo "msgfmt not found; install gettext (brew install gettext)" >&2
	exit 1
fi

moname=xchat

for pofile in `ls "$PO_DIR"/*.po`; do
	locale=`basename $pofile .po`
	modir="$MO_BASE_DIR/$locale/LC_MESSAGES"
	mofile="$modir/$moname.mo"
	pofile="$PO_DIR/$locale.po"

	#pass routine
	if [ "$mofile" -nt "$pofile" ]; then
		if [ $DEBUG ]; then
			echo "pass $locale"
		fi
		continue
	fi

	mkdir -p "$modir"
	cmd="'$MSGFMT' -o '$mofile' '$pofile'"
	if [ $DEBUG ]; then
		echo $cmd
	else
		echo -n $locale' '
	fi
	eval "$cmd"
done
echo 'done'
