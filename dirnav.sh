#!/bin/sh


DIRNAV_STORE_USER=${DIRNAV_STORE_USER:-"$HOME/.config/user.jdmarks"}
DIRNAV_STORE_SESSION=${DIRNAV_STORE_SESSION:-"/tmp/$(id -nu)-$(id -u).jdmarks"}


_dirnav_util_string_reverse() {
	_str=${1:?}
	echo "$_str" | awk '{ for (i = length; i != 0; i--) x = x substr($0, i, 1); } END { print x }'
}


_dirnav_util_path_clean() {
	_path=${1:?}

	_path_old=$(_dirnav_util_string_reverse "$_path")
	_path_new=''
	_skip_segm='0'
	_ifs_bak="$IFS"
	IFS=$(printf '\t')
	for _segm in $(echo "$_path_old" | tr '/' '\t')
	do
		case "$_segm" in
			'.' )
				;;
			'..' )
				_skip_segm=$(($_skip_segm + 1))
				;;
			* )
				if [ "$_skip_segm" -gt 0 ]
				then
					_skip_segm=$(($_skip_segm - 1))
				else
					_path_new="$_path_new$_segm/"
				fi
				;;
		esac
	done
	IFS="$_ifs_bak"

	case "$_path" in
		/* )
			;;
		* )
			while [ "$_skip_segm" -gt 0 ]
			do
				_path_new="$_path_new../"
				_skip_segm=$(($_skip_segm - 1))
			done
			_path_new="$_path_new."
	esac

	case "$_path" in
		*/ )
			_path_new="/$_path_new"
	esac

	_dirnav_util_string_reverse "$_path_new"
}


_dirnav_util_path_diff() {
	_path1="$(_dirnav_util_path_clean "${1:?}")"
	_path2="$(_dirnav_util_path_clean "${2:?}")"

	if [ "$(echo "$_path1" | cut -c1-1)" != "$(echo "$_path2" | cut -c1-1)" ]
	then
		return 1
	fi

	_path1_rev="$(_dirnav_util_string_reverse "$_path1")"
	_path2_rev="$(_dirnav_util_string_reverse "$_path2")"
	while [ "$(basename "$_path1_rev")" = "$(basename "$_path2_rev")" ] \
		&& [ "$(basename "$_path1_rev")" != '/' ] \
		&& [ "$(basename "$_path1_rev")" != '.' ]
	do
		_path1_rev="$(dirname "$_path1_rev")"
		_path2_rev="$(dirname "$_path2_rev")"
	done

	_path_rel="$(_dirnav_util_string_reverse "$_path2_rev")"
	_ifs_bak="$IFS"
	IFS=$(printf '\t')
	set -- $(echo "$_path1_rev" | tr '/' '\t')
	_par_segm="$#"
	IFS="$_ifs_bak"
	while [ "$_par_segm" -gt 0 ] && [ "$_path1_rev" != '.' ]
	do
		_path_rel="../$_path_rel"
		_par_segm=$(($_par_segm - 1))
	done
	_path_rel="./$_path_rel"

	_dirnav_util_path_clean "$_path_rel"
}


_dirnav_util_path_abs() {
	_path="${1:?}"
	_base="${2:-"$PWD"}"

	case "$_path" in
		/* )
			_dirnav_util_path_clean "$_path"
			;;
		* )
			_dirnav_util_path_clean "$_base/$_path"
			;;
	esac
}


_dirnav_util_store_find() {
	_stores=''
	_base="${1:-"$PWD"}"

	if [ "$_dirnav_opt_session" -eq 1 ] && [ -f "$DIRNAV_STORE_SESSION" ]
	then
		_stores="$DIRNAV_STORE_SESSION\t"
	fi

	if [ "$_dirnav_opt_local" -eq 1 ]
	then
		_dir="$_base"
		while [ "$_dir" != '/' ]
		do
			if [ -f "$_dir/.jdmarks" ]
			then
				_stores="$_stores$_dir/.jdmarks\t"

				if [ "$_dirnav_internal_nearest" -eq 1 ]
				then
					break
				fi
			fi
			_dir="$(dirname "$_dir")"
		done
	fi

	if [ "$_dirnav_opt_global" -eq 1 ] && [ -f "$DIRNAV_STORE_USER" ]
	then
		_stores="$_stores$DIRNAV_STORE_USER\t"
	fi

	echo "$_stores"
}


_dirnav_action_create() {
	_path="${1:?}"

	if [ ! -d "$_path" ]
	then
		echo "jd: no such directory: $_path" 1>&2
		return 3
	fi

	_path="$(_dirnav_util_path_abs "$_path/.jdmarks")"

	if [ "$_dirnav_opt_dryrun" -eq 1 ] || [ "$_dirnav_opt_verbose" -eq 1 ]
	then
		echo "creating: $_path"
	fi
	if [ "$_dirnav_opt_dryrun" -eq 0 ]
	then
		touch "$_path"
	fi
	return 0
}


_dirnav_action_query() {
	_mark="${1:?}"

	if [ "$_dirnav_opt_global" -eq 0 ] \
		&& [ "$_dirnav_opt_local" -eq 0 ] \
		&& [ "$_dirnav_opt_session" -eq 0 ]
	then
		_dirnav_opt_global=1
		_dirnav_opt_local=1
		_dirnav_opt_session=1
	fi
	_dirnav_internal_nearest=0
	_stores="$(_dirnav_util_store_find)"

	_ifs_bak="$IFS"
	IFS=$(printf '\t')
	for _store in $(echo "$_stores")
	do
		if [ "$_dirnav_opt_verbose" -eq 1 ]
		then
			echo "searching: $_store"
		fi

		_target="$(awk -F '\t' "/^$_mark\t/ { print \$2; exit 7 }" "$_store")"
		if [ $? -eq 7 ]
		then
			if [ "$_dirnav_opt_asis" -eq 1 ]
			then
				if [ "$_dirnav_opt_dryrun" -eq 1 ] || [ "$_dirnav_opt_verbose" -eq 1 ]
				then
					echo "$_target"
				fi
				if [ "$_dirnav_opt_dryrun" -eq 0 ]
				then
					cd "$_target"
				fi
			else
				if [ "$_dirnav_opt_dryrun" -eq 1 ] || [ "$_dirnav_opt_verbose" -eq 1 ]
				then
					case "$_target" in
						./* )
							_dirnav_util_path_clean "$(dirname "$_store")/$_target"
							;;
						* )
							echo "$_target"
							;;
					esac
				fi
				if [ "$_dirnav_opt_dryrun" -eq 0 ]
				then
					case "$_target" in
						./* )
							cd "$(_dirnav_util_path_clean "$(dirname "$_store")/$_target")"
							;;
						* )
							cd "$_target"
							;;
					esac
				fi
			fi
			IFS="$_ifs_bak"
			return 0
		fi
	done
	IFS="$_ifs_bak"

	echo "jd: no such mark: $_mark" 1>&2
	return 3
}


_dirnav_action_add() {
	_mark="${1:?}"
	_target="${2:?}"

	if [ "$_dirnav_opt_global" -eq 0 ] \
		&& [ "$_dirnav_opt_local" -eq 0 ] \
		&& [ "$_dirnav_opt_session" -eq 0 ]
	then
			_dirnav_opt_session=1
	fi

	_path="$_target"
	if [ "$_dirnav_opt_asis" -eq 0 ]
	then
		if [ "$_dirnav_opt_force" -eq 0 ] && [ ! -d "$_path" ]
		then
			echo "jd: no such directory: $_path" 1>&2
			return 3
		fi
		_path=$(_dirnav_util_path_abs "$_path")
	fi

	if [ "$_dirnav_opt_session" -eq 1 ]
	then
		if [ "$_dirnav_opt_verbose" -eq 1 ]
		then
			echo "adding to: $DIRNAV_STORE_SESSION"
		fi

		if [ "$_dirnav_opt_dryrun" -eq 1 ]
		then
			printf "%s\t%s\n" "$_mark" "$_path"
		else
			touch "$DIRNAV_STORE_SESSION"
			grep -v "^$_mark	" "$DIRNAV_STORE_SESSION" > "$DIRNAV_STORE_SESSION.tmp"
			printf "%s\t%s\n" "$_mark" "$_path" >> "$DIRNAV_STORE_SESSION.tmp"
			sort "$DIRNAV_STORE_SESSION.tmp" > "$DIRNAV_STORE_SESSION"
			rm -f "$DIRNAV_STORE_SESSION.tmp"
		fi
	fi

	if [ "$_dirnav_opt_local" -eq 1 ]
	then
		_dir="$PWD"
		while [ "$_dir" != '/' ]
		do
			if [ -f "$_dir/.jdmarks" ]
			then
				if [ "$_dirnav_opt_verbose" -eq 1 ]
				then
					echo "adding to: $_dir/.jdmarks"
				fi

				if [ "$_dirnav_opt_asis" -eq 0 ]
				then
					_path_rel=$(_dirnav_util_path_diff "$_dir" "$_path")
				fi

				if [ "$_dirnav_opt_dryrun" -eq 1 ]
				then
					printf "%s\t%s\n" "$_mark" "$_path_rel"
				else
					touch "$_dir/.jdmarks"
					grep -v "^$_mark	" "$_dir/.jdmarks" > "$_dir/.jdmarks.tmp"
					printf "%s\t%s\n" "$_mark" "$_path_rel" >> "$_dir/.jdmarks.tmp"
					sort "$_dir/.jdmarks.tmp" > "$_dir/.jdmarks"
					rm -f "$_dir/.jdmarks.tmp"
				fi
				break
			fi
			_dir="$(dirname "$_dir")"
		done
	fi

	if [ "$_dirnav_opt_global" -eq 1 ]
	then
		if [ "$_dirnav_opt_verbose" -eq 1 ]
		then
			echo "adding to: $DIRNAV_STORE_USER"
		fi

		if [ "$_dirnav_opt_dryrun" -eq 1 ]
		then
			printf "%s\t%s\n" "$_mark" "$_path"
		else
			touch "$DIRNAV_STORE_USER"
			grep -v "^$_mark	" "$DIRNAV_STORE_USER" > "$DIRNAV_STORE_USER.tmp"
			printf "%s\t%s\n" "$_mark" "$_path" >> "$DIRNAV_STORE_USER.tmp"
			sort "$DIRNAV_STORE_USER.tmp" > "$DIRNAV_STORE_USER"
			rm -f "$DIRNAV_STORE_USER.tmp"
		fi
	fi

	return 0
}


_dirnav_action_remove() {
	_mark="${1:?}"

	if [ "$_dirnav_opt_global" -eq 0 ] \
		&& [ "$_dirnav_opt_local" -eq 0 ] \
		&& [ "$_dirnav_opt_session" -eq 0 ]
	then
			_dirnav_opt_session=1
	fi
	_dirnav_internal_nearest=1
	_stores="$(_dirnav_util_store_find)"

	_found=0
	_ifs_bak="$IFS"
	IFS=$(printf '\t')
	for _store in $(echo "$_stores")
	do
		if [ "$(grep -c "^$_mark	" "$_store")" -gt 0 ]
		then
			_found=1

			if [ "$_dirnav_opt_verbose" -eq 1 ]
			then
				echo "removing from: $_store"
			fi
			if [ "$_dirnav_opt_dryrun" -eq 1 ]
			then
				grep "^$_mark	" "$_store"
			else
				grep -v "^$_mark	" "$_store" > "$_store.tmp"
				mv -f "$_store.tmp" "$_store"
			fi
		fi
	done
	IFS="$_ifs_bak"

	if [ $_found -eq 0 ]
	then
		echo "jd: no such mark: $_mark" 1>&2
		return 3
	fi
	return 0
}


_dirnav_action_list() {
	if [ "$_dirnav_opt_global" -eq 0 ] \
		&& [ "$_dirnav_opt_local" -eq 0 ] \
		&& [ "$_dirnav_opt_session" -eq 0 ]
	then
			_dirnav_opt_session=1
	fi
	_dirnav_internal_nearest=1
	_stores="$(_dirnav_util_store_find)"

	_ifs_bak="$IFS"
	IFS=$(printf '\t')
	for _store in $(echo "$_stores")
	do
		if [ "$_dirnav_opt_verbose" -eq 1 ]
		then
			echo "listing: $_store"
		fi

		awk -F '\t' "{ print \$1 }" "$_store"
	done
	IFS="$_ifs_bak"

	return 0
}


_dirnav_help_jd() {
	echo "Usage: jd [OPTIONS] <MARK>             query mark <MARK>, and switch to its directory"
	echo "       jd [OPTIONS] <MARK> <TARGET>    create a mark <MARK> pointing to <TARGET>"
	echo "       jd [OPTIONS] -d <MARK>          delete mark <MARK>"
	echo "       jd [OPTIONS] -L                 list marks"
	echo "       jd -c <DIR>                     create local store at directory <DIR>"
	echo
	echo "Options:"
	echo "  -g           use global store"
	echo "  -l           use local store"
	echo "  -s           use session store"
	echo "  -n           dryrun"
	echo "  -f           force create mark"
	echo "  -F           create/query mark as-is"
	echo "  -c <DIR>     create local store at <DIR>"
	echo "  -d <MARK>    delete mark"
	echo "  -L           list marks"
	echo "  -v           verbose"
	echo "  -h           print help text"
	echo
	echo "The global store is persistent, and available in the entire directory tree."
	echo "The local store is persistent, and available in its directory and subdirectories."
	echo "The session store is not persistent (it may be lost across reboots), and available"
	echo "in the entire directory tree."
	echo
	echo "When querying a mark, all stores will be searched by default."
	echo
	echo "When creating, deleting or listing marks, the session store will be used by default. When"
	echo "specifying -l (use local store), only the nearest directory-local store will be used."
}


_dirnav_cmd_ad() {
	cd "$OLDPWD"
}


_dirnav_cmd_bd() {
	_target_dir="$*"

	if [ -z "$_target_dir" ]
	then
		cd ..
		return 0
	fi

	_curr_path=$(dirname "$PWD")
	while [ "$_curr_path" != '/' ]
	do
		_curr_dir=$(basename "$_curr_path")

		case "$_curr_dir" in
			*$_target_dir* )
				cd "$_curr_path"
				return 0
				;;
		esac

		_curr_path=$(dirname "$_curr_path")
	done

	echo "bd: no parent directory containing: $_target_dir" 1>&2
	return 3
}


_dirnav_cmd_jd() {
	_dirnav_opt_dryrun=0
	_dirnav_opt_global=0
	_dirnav_opt_local=0
	_dirnav_opt_session=0
	_dirnav_opt_create=''
	_dirnav_opt_delete=0
	_dirnav_opt_list=0
	_dirnav_opt_force=0
	_dirnav_opt_asis=0
	_dirnav_opt_help=0
	_dirnav_opt_verbose=0

	while getopts ":nglsc:dLfFhv" _opt
	do
		case "$_opt" in
			n )
				_dirnav_opt_dryrun=1
				;;
			g )
				_dirnav_opt_global=1
				;;
			l )
				_dirnav_opt_local=1
				;;
			s )
				_dirnav_opt_session=1
				;;
			c )
				_dirnav_opt_create="$OPTARG"
				;;
			d )
				_dirnav_opt_delete=1
				;;
			L )
				_dirnav_opt_list=1
				;;
			f )
				_dirnav_opt_force=1
				;;
			F )
				_dirnav_opt_asis=1
				;;
			h )
				_dirnav_opt_help=1
				;;
			v )
				_dirnav_opt_verbose=1
				;;
			\? )
				echo "jd: invalid option: -$OPTARG" 1>&2
				return 1
				;;
			: )
				echo "jd: option requires argument: -$OPTARG" 1>&2
				return 1
				;;
		esac
	done
	shift $(($OPTIND - 1))
	_dirnav_opt_mark_name="$1"
	_dirnav_opt_mark_target="$2"

	if [ "$_dirnav_opt_help" -eq 1 ]
	then
		_dirnav_help_jd
		return 0
	fi

	if { [ ! -z "$_dirnav_opt_create" ] && [ $# -ne 0 ] ; } \
		|| { [ "$_dirnav_opt_delete" -eq 1 ] && [ $# -ne 1 ] ; } \
		|| { [ "$_dirnav_opt_list" -eq 1 ] && [ $# -ne 0 ] ; } \
		|| { [ ! -z "$_dirnav_opt_create" ] && [ "$_dirnav_opt_list" -eq 1 ] ; } \
		|| { [ -z "$_dirnav_opt_create" ] && [ "$_dirnav_opt_list" -eq 0 ] && { [ $# -lt 1 ] || [ $# -gt 2 ] ; } ; }
	then
		_dirnav_help_jd
		return 1
	fi

	if [ ! -z "$_dirnav_opt_create" ]
	then
		_dirnav_action_create "$_dirnav_opt_create"
		return $?
	fi

	if [ "$_dirnav_opt_delete" -eq 1 ]
	then
		_dirnav_action_remove "$1"
		return $?
	fi

	if [ "$_dirnav_opt_list" -eq 1 ]
	then
		_dirnav_action_list
		return $?
	fi

	if [ $# -eq 1 ]
	then
		_dirnav_action_query "$1"
		return $?
	fi

	if [ $# -eq 2 ]
	then
		_dirnav_action_add "$1" "$2"
		return $?
	fi
}


if [ "${DIRNAV_REGISTER_AD:-1}" != "0" ]
then
	alias ad='_dirnav_cmd_ad'
fi

if [ "${DIRNAV_REGISTER_BD:-1}" != "0" ]
then
	alias bd='_dirnav_cmd_bd'
fi

if [ "${DIRNAV_REGISTER_JD:-1}" != "0" ]
then
	alias jd='_dirnav_cmd_jd'
fi

