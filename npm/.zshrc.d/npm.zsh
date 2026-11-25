#
export NPM_CONFIG_PREFIX="${HOME}/.npm-global"

if [ ! -d "${NPM_CONFIG_PREFIX}" ]; then
  mkdir -p "${NPM_CONFIG_PREFIX}"
fi

case ":${PATH}:" in
  *":${NPM_CONFIG_PREFIX}/bin:"*) ;;
  *) export PATH="${NPM_CONFIG_PREFIX}/bin:${PATH}" ;;
esac
