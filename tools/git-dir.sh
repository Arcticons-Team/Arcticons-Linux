#!/bin/bash

# author: Marcos Oliveira <terminalroot.com.br>
# describe: Clone Only a Git Subdirectory
# version: 1.0
# license: GNU GPLv3

if [[ "$(echo $LANG | cut -c 1-2)" != "pt" ]]; then
	declare -x l=( "usage" 
		       "Use this flag to inform the REPOSITORY, this option is not optional." 
		       "Use this flag to inform the Directory/Subdirectory, this option is not optional."
		       "If you want to clone with a new name."
		       "Enter only the repository without subdirectory for the '-r' parameter."
		       "Parameters"
		       "Options"
		       "version"
		     )
else
	declare -x l=( "uso" 
		       "Use este sinalizador para informar o REPOSITÓRIO, esta opção não é opcional." 
		       "Use este sinalizador para informar o Diretório/Subdiretório, esta opção não é opcional."
		       "Se você desejar clonar com um novo nome."
		       "Digite apenas o repositório sem subdiretório para o parâmetro '-r'."
		       "Parâmetros"
		       "Opções"
		       "versão" #7
		      )

fi

usage(){
  cat <<EOF
${l[0]}: ${0##*/} -r REPOSITORY -s SUBDIR [-d NAMEDIR]
  
  ${l[5]}:
    -r REPOSITORY  ${l[1]}
    -s SUBDIR	   ${l[2]}

  ${l[6]}:
    -d NAMEDIR     ${l[3]}

* git-dir ${l[7]} 1.0 - Marcos Oliveira <contato@terminalroot.com.br>
** ${l[4]}
EOF

[[ ! -z "$1" ]] && exit 1

}

git-dir(){

	[[ -z $r || -z $s ]] && usage 1
	[[ ! -z $(echo "${r}" | cut -d"/" -f6) ]] && usage | tail -n 1 && exit 1
	[[ -z $(echo "${r}" | cut -d"/" -f5) ]] && usage 1
	p=$(basename "${r}")
	[[ ! -z "${d}" ]] && paramd="${d}" || paramd=
	[[ -d "/tmp/gitdir" ]] && rm -rf "/tmp/gitdir"
	mkdir "/tmp/gitdir"
	cd "/tmp/gitdir"
	git init
	git remote add -f origin $r
	git config core.sparseCheckout true
	echo "${s}" >> .git/info/sparse-checkout
	git pull origin master
	cd -
	mv "/tmp/gitdir/${s}" "./${paramd}"
	exit 0

}

while getopts 'r:s:d:' flags 2>&-; do
	case "$flags" in
		r) [[ -z "${OPTARG}" ]] && usage 1 || r=$OPTARG;;
		s) [[ -z "${OPTARG}" ]] && usage 1 || s=$OPTARG;;
		d) [[ -z "${OPTARG}" ]] && usage 1 || d=$OPTARG;;
		*) usage 1;;
	esac
done
git-dir

# vim: et ts=2 sw=2 ft=sh: