#!/bin/bash

EXPORT="../Arcticons/"
ICON="../Arcticons/scalable/apps"

for DIR in $(find -name "*.svg")
do
  if [[ -L ${DIR} ]]; then
  FILE=${DIR##*/}
  NAME=${FILE%.*}
  cp ${FILE} ${FILE}.tmp
  rm ${FILE}.tmp
  cp -f ${FILE} ${ICON}/${FILE}
  for SIZE in ${SIZES}
  do
    cp ${NAME}.svg ${NAME}.png
    case ${SIZE} in
      8)
	mv ${NAME}.png ${EXPORT}/8x8/apps/
	;;

      16)
	mv ${NAME}.png ${EXPORT}/16x16/apps/
	;;
      24)
	mv ${NAME}.png ${EXPORT}/24x24/apps/
	;;
      32)
	mv ${NAME}.png ${EXPORT}/32x32/apps/
	;;
      48)
	mv ${NAME}.png ${EXPORT}/48x48/apps/
	;;
      128)
	mv ${NAME}.png ${EXPORT}/128x128/apps/
	;;
      256)
	mv ${NAME}.png ${EXPORT}/256x256/apps/
    esac
  done
  rm ${FILE}
  fi
done
