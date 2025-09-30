#!/usr/bin/zsh

notebook() {
  if ! app ipython check; then
    app ipython install
  fi

  if ! app jupytext check; then
    app jupytext install
  fi

  if [ $# -lt 2 ]; then
    echo "Usage: $0 [notebook] <command> [args...]"
    return 1
  fi
  
  local NOTEBOOK=$1
  local COMMAND=$2
  shift 2

  if [ ! -f "${NOTEBOOK}" ]; then
    echo "Notebook does not exist."
    return 1
  fi

  case "${COMMAND}" in
    "execute")
      #jupytext --execute $NOTEBOOK
      notebook ${NOTEBOOK} sync >/dev/null 2>&1
      NOTEBOOK=$(echo "${NOTEBOOK}" | sed 's/\.md$/.ipynb/')
      ipython -c "%run ${NOTEBOOK}"
      ;;
    "sync")
      jupytext --sync ${NOTEBOOK}
      ;;
    "convert")
      jupytext --set-formats ipynb,md ${NOTEBOOK}
      ;;
    "edit")
      notebook ${NOTEBOOK} sync >/dev/null 2>&1
      NOTEBOOK=$(echo "${NOTEBOOK}" | sed 's/\.ipynb$/.md/')
      ${EDITOR} ${NOTEBOOK}
      notebook ${NOTEBOOK} sync >/dev/null 2>&1
      ;;
    *)
      echo "Unknown command: $0 ${COMMAND}"
      ;;
  esac
}

