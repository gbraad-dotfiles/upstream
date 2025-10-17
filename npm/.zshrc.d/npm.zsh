#
export NPMGLOBAL=${HOME}/.npm-global

if [ ! -d "${NPMGLOBAL}" ]; then
  mkdir -p ${NPMGLOBAL}
fi

export PATH=${NPMGLOBAL}/bin:$PATH

