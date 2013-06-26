#!/bin/bash 
#===============================================================================
#
#          FILE:  apt-sn.sh
# 
#         USAGE:  ./apt-sn.sh -d -h patern
# 
#   DESCRIPTION:  Wrapper on 'apt-cache search' to search packages by name or description. By default searches only by name.
# 				As the search patern you can give a few words.
# 
#       OPTIONS:  -d -h
#  REQUIREMENTS:  debian: apt-cache, bash(>=4)
#          BUGS:  ---
#         NOTES:  ---
#        AUTHOR: Piotr Rogoża (piecia), rogoza.piotr@gmail.com
#       COMPANY: 
#       CREATED: 10.12.2010 10:23:46 CET
#       VERSION: 1.0
#      REVISION:  ---
#===============================================================================

# Parametry startowe
if ! which apt-cache &>/dev/null; then
	echo "apt-cache not found. Is it Debian?" 1>&2
	exit 1
fi
if ! type readarray &>/dev/null; then
	echo "This script requirements bash>4 with readarray built-in function" 1>&2
	exit 1
fi

## Zmienne startowe
SEARCHOPTIONS="--names-only"
OPTIONS="hd"
#h - pomoc
#f - wyświetla dodatkowo szczegółowy opis pakietu, jak apt-cache show
#d - szuka także w opisach
# Kolory
colornr="\033[0;30;0;43m" #ciemnożółte tło, czarny napis
colorstatus="\033[0;30;1;43m" #zółte tło, czarny napis
colorversion="\033[1;32m" #zielony
colorname="\033[1;37m" #biały
colorprompt="\033[1;33m" #żółty
coloroff="\033[0m" 
## Funkcje
usage(){ #{{{
	echo "Usage: $(basename $0) -h|-d"
	echo "-h - display this help"
	echo "-d - search in descriptions too"
	echo "Use this script logged in as root or use the sudo"
} #}}}
aptcache(){ #{{{
# Wypisuje wyszukane pakiety na &3 i pakiety z opisami na &1
	if [ "$1" == "--get-res" ]; then
		apt-cache search $SEARCHOPTIONS $SEARCHPACKAGE | awk \
		-vcolornr=$colornr -vcolorstatus=$colorstatus -vcolorversion=$colorversion -vcolorname=$colorname -vcoloroff=$coloroff '{
		printf $1"\n">"/proc/self/fd/3"; 
		nazwa=$1;
		old=$0
		command = "dpkg -l "$1" 2>/dev/null | tail -n1";
		command | getline status1;
		close(command);
		if (status1 == ""){
			status="Not installed";
		} else {
			split(status1,tablica);
			status=tablica[1];
			if ( status == "ii") {
				version=tablica[3];
			}
		}
		print colornr NR coloroff ,colorname nazwa coloroff, colorversion version coloroff, colorstatus status coloroff;
		# print description
		printf "    ";
		for (i=3;i<=NF;i++)
			printf ($i" ");
		printf "\n";
	}'
	fi
}	# eof aptcache }}}
search(){  #{{{
# return: global var PKGSFOUND
	{ readarray -t PKGSFOUND < <(aptcache --get-res 3>&1 1>&2 ); } 2>&1
}	# eof search }}}
_showmsg(){ #{{{
# $1 kolor, wiadomość
	echo -en "$1==> ${colorname}$2${coloroff}"
} #}}}
aptget_install(){ #{{{
# instaluje pakiety przekazane przez zmienną globalną packages
	[[ $args ]] || exit 0
	[ "$(whoami)" = root ] || { echo "You aren't root, please log in as root, or let use sudo" 1>&2; exit 1; }
	for i in $args; do
		_showmsg $colorprompt "Installing $i\n"
		apt-get install $i
	done
}	# eof aptget_install }}}
set -- $(getopt $OPTIONS $*)
SEARCHPACKAGE="$*"
SEARCHPACKAGE=${SEARCHPACKAGE##*--}
while getopts $OPTIONS OPT; do
	case $OPT in
		h)
		usage
		exit 0
		;;
		f)
		SEARCHOPTIONS+=" --full"
		;;
		d)
		SEARCHOPTIONS=${SEARCHOPTIONS/--names-only/}	
		;;
		*)
		echo "Parametr $OPT nie obsługiwany" 1>&2
		exit 1
		;;
	esac
done
search 
[[ $PKGSFOUND ]] || exit 0
_showmsg $colorprompt "Enter n° of packages to be installed (ex: 1 2 3 or 1-3)\n"
_showmsg $colorprompt "-------------------------------------------------------\n"
_showmsg $colorprompt 
read -ea packagesnum
[[ $packagesnum ]] || exit 0
for line in ${packagesnum[@]/,/ }; do
	(( line )) || exit 1	# not a number, range neither 
	(( ${line%-*}-1 < ${#PKGSFOUND[@]} )) || exit 1	# > no package corresponds
	if [[ ${line/-/} != $line ]]; then
		for ((i=${line%-*}-1; i<${line#*-}; i++)); do
			packages+=(${PKGSFOUND[$i]});
		done
	else
		packages+=(${PKGSFOUND[$((line - 1))]})
	fi
done
args=("${packages[*]}")
aptget_install

exit 0
