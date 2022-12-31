#!/usr/bin/env zsh


source ${0:A:h}/dirnav.sh


function _dirnav_compl_zsh_bd() {
	local _dirs=(${(s:/:)$(dirname "$PWD")})
	_dirs=(${(Oa)_dirs})

	reply=()
	for _dir in $_dirs
	do
		case "$_dir" in
			*$1* )
				reply=($reply "$_dir")
				;;
		esac
	done
}
compctl -k "()" -x 'm[1,2]' -V directories -U -K _dirnav_compl_zsh_bd -- _dirnav_cmd_bd


function _dirnav_compl_zsh_jd_marks() {
	_dirnav_opt_global=0
	_dirnav_opt_local=0
	_dirnav_opt_session=0
	_dirnav_opt_delete=0
	_dirnav_internal_nearest=0

	_cmdline=($words '-N')
	_cmd=("_dirnav_cmd_jd")
	while getopts ":glsd" _opt ${_cmdline:|_cmd}
	do
		case "$_opt" in
			g )
				_dirnav_opt_global=1
				;;
			l )
				_dirnav_opt_local=1
				;;
			s )
				_dirnav_opt_session=1
				;;
			d )
				_dirnav_opt_delete=1
				;;
			\? )
				;;
			: )
				;;
		esac
	done
	local _dirnav_opt_mark_name="$words[$CURRENT]"

	if [ "$_dirnav_opt_global" -eq 0 ] \
		&& [ "$_dirnav_opt_local" -eq 0 ] \
		&& [ "$_dirnav_opt_session" -eq 0 ]
	then
		if [ "$_dirnav_opt_delete" -eq 1 ]
		then
			_dirnav_opt_session=1
			_dirnav_internal_nearest=1
		else
			_dirnav_opt_global=1
			_dirnav_opt_local=1
			_dirnav_opt_session=1
		fi
	fi
	local _stores=$(_dirnav_util_store_find)

	_ifs_bak="$IFS"
	IFS=$(printf '\t')
	for _store in $(echo $_stores)
	do
		local _marks="$(awk -F '\t' "/^$_opt_mark_name/ { print \$1 }" "$_store")"
		IFS=$'\n'
		for _mark in $(echo $_marks)
		do
			compadd "$@" "$_mark"
		done
		IFS=$(printf '\t')
	done
	IFS="$_ifs_bak"
}
function _dirnav_compl_zsh_jd() {
	_arguments -s -w -A '-*' : \
		'(-c)-g[use global store]' \
		'(-c)-l[use local store]' \
		'(-c)-s[use session store]' \
		'(-g -l -s -d -L -f -F 1 2)-c[create local store]:path:_path_files -\/' \
		'(-c -L -f -F 2)-d[delete mark]' \
		'(-c -d -f -F 1 2)-L[list marks]' \
		'(-c -d -L)-f[force create mark]' \
		'(-c -d -L)-F[create mark as-is]' \
		'-n[dryrun]' \
		'-v[verbose]' \
		'1:mark:_dirnav_compl_zsh_jd_marks' \
		'2:target:_path_files -\/' \
}
compdef _dirnav_compl_zsh_jd _dirnav_cmd_jd

