#!/bin/sh

# usage: sh mk-profile.sh <profile>

find_profile(){
	local files=$(ls ${profile_dir}/Packages*)
	for f in ${files[@]};do
		case $f in
			${profile_dir}/Packages-Root|${profile_dir}/Packages-Live|${profile_dir}/Packages-Mhwd) continue ;;
			*) packages_custom="$f" ;;
		esac
	done
}

get_shared_list(){
	local path
	case ${edition} in
		sonar|netrunner) path=${run_dir}/shared/${edition}/Packages-Desktop ;;
		*) path=${run_dir}/shared/manjaro/Packages-Desktop ;;
	esac
	echo $path
}

load_profile_config(){

	[[ -f $1 ]] || return 1

	profile_conf="$1"

	[[ -r ${profile_conf} ]] && source ${profile_conf}

	[[ -z ${multilib} ]] && multilib="true"

	[[ -z ${nonfree_mhwd} ]] && nonfree_mhwd="true"

	return 0
}

load_pkgs(){


	local _init _init_rm _multi _nonfree_default _nonfree_multi _arch _arch_rm _nonfree_i686 _nonfree_x86_64

	if [[ ${initsys} == 'openrc' ]];then
		_init="s|>openrc||g"
		_init_rm="s|>systemd.*||g"
	else
		_init="s|>systemd||g"
		_init_rm="s|>openrc.*||g"
	fi
	if [[ "$2" == "i686" ]]; then
		_arch="s|>i686||g"
		_arch_rm="s|>x86_64.*||g"
		_multi="s|>multilib.*||g"
		_nonfree_multi="s|>nonfree_multilib.*||g"
		_nonfree_x86_64="s|>nonfree_x86_64.*||g"
		if ${nonfree_mhwd};then
			_nonfree_default="s|>nonfree_default||g"
			_nonfree_i686="s|>nonfree_i686||g"

		else
			_nonfree_default="s|>nonfree_default.*||g"
			_nonfree_i686="s|>nonfree_i686.*||g"
		fi
	else
		_arch="s|>x86_64||g"
		_arch_rm="s|>i686.*||g"
		_nonfree_i686="s|>nonfree_i686.*||g"
		if ${multilib};then
			_multi="s|>multilib||g"
			if ${nonfree_mhwd};then
				_nonfree_default="s|>nonfree_default||g"
				_nonfree_x86_64="s|>nonfree_x86_64||g"
				_nonfree_multi="s|>nonfree_multilib||g"
			else
				_nonfree_default="s|>nonfree_default.*||g"
				_nonfree_multi="s|>nonfree_multilib.*||g"
				_nonfree_x86_64="s|>nonfree_x86_64.*||g"
			fi
		else
			_multi="s|>multilib.*||g"
			if ${nonfree_mhwd};then
				_nonfree_default="s|>nonfree_default||g"
				_nonfree_x86_64="s|>nonfree_x86_64||g"
				_nonfree_multi="s|>nonfree_multilib.*||g"
			else
				_nonfree_default="s|>nonfree_default.*||g"
				_nonfree_x86_64="s|>nonfree_x86_64.*||g"
				_nonfree_multi="s|>nonfree_multilib.*||g"
			fi
		fi
	fi
	local _blacklist="s|>blacklist.*||g" \
		_kernel="s|KERNEL|$kernel|g" \
		_used_kernel=${kernel:5:2} \
		_space="s| ||g" \
		_clean=':a;N;$!ba;s/\n/ /g' \
		_com_rm="s|#.*||g" \
		_purge="s|>cleanup.*||g" \
		_purge_rm="s|>cleanup||g"

	list=$1
	sort -u $(get_shared_list) ${packages_custom} > packages-desktop.list
	list=packages-desktop.list

	packages=$(sed "$_com_rm" "$list" \
			| sed "$_space" \
			| sed "$_blacklist" \
			| sed "$_purge" \
			| sed "$_init" \
			| sed "$_init_rm" \
			| sed "$_arch" \
			| sed "$_arch_rm" \
			| sed "$_nonfree_default" \
			| sed "$_multi" \
			| sed "$_nonfree_i686" \
			| sed "$_nonfree_x86_64" \
			| sed "$_nonfree_multi" \
			| sed "$_kernel" \
			| sed "$_clean")
	rm $list
}

get_edition(){
	local result=$(find ${run_dir} -maxdepth 2 -name "$1") path
	path=${result%/*}
	echo ${path##*/}
}

write_profile_yaml(){
	[[ ! -d ${run_dir}/shared/netinstall/${profile} ]] && mkdir ${run_dir}/shared/netinstall/${profile}
	out=${run_dir}/shared/netinstall/${profile}/$1-$2.yaml

	echo "- name: '${profile}-$1-$2'" > $out
	echo "  description: '${profile^^} Desktop'" >> $out
	echo "  packages:" >> $out
	for p in ${packages[@]};do
		echo "       - $p" >> $out
	done
}

run_dir=../..

kernel=linux47
profile=$1

edition=$(get_edition ${profile})
profile_dir=${run_dir}/${edition}/${profile}

find_profile

for a in "i686" "x86_64";do
	for i in "systemd" "openrc";do
		load_profile_config "${profile_dir}/profile.conf"
		load_pkgs "${packages_custom}" "$a"
		write_profile_yaml "$a" "$i"
	done
done
