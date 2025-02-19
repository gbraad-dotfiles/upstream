#!/usr/bin/zsh

CONFIG="${HOME}/.config/dotfiles/secrets"
alias secretsini="git config -f ${CONFIG}"

_secretspath=$(secretsini --get secrets.path || echo "${HOME}/.dotsecrets")
eval _secretspath=$(echo ${_secretspath})

_secretsexists() {
    if [ -d "${_secretspath}" ]; then
        return 0  # File exists, return true (0)
    else
        return 1  # File does not exist, return false (1)
    fi
}

vim_decrypt_file() {
  local file="$1"
  local password="$2"

  # Use vim in ex mode to decrypt the file
  printf "%s\n" "$password" | vim -n -E -s "$file" \
    -c 'set nomore' \
    -c '%print' \
    -c 'q!' 2>/dev/null
}

vim_encrypt_file() {
  local file="$1"
  local password="$2"
  local content="$3"

  # Create a temporary file with the content
  local temp_file=$(mktemp)
  printf "%s" "$content" > "$temp_file"

  # Use vim in ex mode to encrypt the file
  # Double password entry: first for setting, second for verification
  printf "%s\n%s\n" "$password" "$password" | vim -n -E -s "$temp_file" \
    -c 'set cm=blowfish2' \
    -c 'X' \
    -c 'w! '"$file" \
    -c 'q!' 2>/dev/null

  # Clean up the temporary file
  rm -f "$temp_file"

  # Verify the file exists and is not empty
  if [ ! -s "$file" ]; then
    echo "Error: Failed to encrypt file"
    return 1
  fi
}

add_secret() {
  if ! _secretsexists; then
    _clonesecrets
  fi

  # Get the password for encryption
  local vimcrypt_password=$(read_password "Enter password for encryption")

  # Read the secret content
  echo "Enter the secret content (press Enter, then Ctrl+D to finish):"
  local content
  content=$(cat)

  # Prompt for the secret name if not provided
  local secret_name
  if [ "$#" -eq 1 ]; then
    secret_name="$1"
  else
    echo "Enter the secret name: "
    read secret_name
  fi

  # Ensure we have a name
  if [ -z "$secret_name" ]; then
    echo "Error: Secret name is required"
    return 1
  fi

  local secret_file="${_secretspath}/secrets/${secret_name}"

  # Ensure the secrets directory exists
  mkdir -p "${_secretspath}/secrets"

  # Encrypt and save the content
  if ! vim_encrypt_file "$secret_file" "$vimcrypt_password" "$content"; then
    echo "Failed to encrypt secret"
    return 1
  fi

  echo "Secret has been encrypted and saved to $secret_file"

  # If we're in a git repository, stage the new file
  if [ -d "${_secretspath}/.git" ]; then
    (cd "${_secretspath}" && git add "secrets/${secret_name}")
    echo "The secret file has been staged in git. Don't forget to commit and push your changes."
  fi
}

read_password() {
  local old_tty=$(stty -g </dev/tty)
  
  stty -echo </dev/tty
    
  local password=""
  if [ -n "$1" ]; then
    printf "%s: " "$1" >&2
  else
    printf "Password: " >&2
  fi
    
  read password </dev/tty
  printf "\n" >&2

  stty "$old_tty" </dev/tty
    
  printf "%s" "$password"
}

_clonesecrets() {
  local repo=$(secretsini --get secrets.repository)
  git clone ${repo} ${_secretspath} --depth 2
}

get_secret() {
  if ! _secretsexists; then
    _clonesecrets
  fi

  local vimcrypt_file
  if [ -z "$1" ]; then
    secret_name=$(cd "${_secretspath}/secrets" && find . -type f -not -path '*/\.*' | sed 's|^\./||' | fzf)
    if [ -z "${secret_name}" ]; then
      echo "Empty selection"
      return 1
    fi
    vimcrypt_file="${_secretspath}/secrets/${secret_name}"
  else
    vimcrypt_file="${_secretspath}/secrets/$1"
  fi

  local vimcrypt_password=$(read_password "Enter the password for the secret")
  local decrypted_text=$(vim_decrypt_file "$vimcrypt_file" "$vimcrypt_password")

  echo "$decrypted_text"
}

var_secret() {
  local secret_name="$1"
  if [ -z "$1" ]; then
    secret_name=$(cd "${_secretspath}/secrets" && find . -type f -not -path '*/\.*' | sed 's|^\./||' | fzf)
    if [ -z "${secret_name}" ]; then
      echo "Empty selection"
      return 1
    fi
  else
    secret_name="$1"
  fi

  local env_var_name=$(echo "${secret_name}" | tr '[:lower:]-' '[:upper:]_')
        
  # Decrypt and store the content
  local secret_content
  secret_content=$(get_secret "${secret_name}")
    
  # Check if decryption was successful
  if [ -z "${secret_content}" ]; then
    printf "Error: Failed to decrypt secret '%s'\n" "${secret_name}" >&2
    return 1
  fi
    
  # Export to environment variable
  export "$env_var_name=${secret_content}"
    
  # Optionally notify that the secret was loaded (to stderr to avoid affecting pipes)
  printf "Loaded secret '%s' into environment variable '%s'\n" "${secret_name}" "${env_var_name}" >&2
}

file_secret() {
  if [ "$#" -ne 2 ]; then
    echo "Usage: file_secret <secret_name> <output_file>"
    return 1
  fi

  local secret_name="$1"
  local output_file="$2"

  if ! _secretsexists; then
    _clonesecrets
  fi

  local vimcrypt_file="${_secretspath}/secrets/${secret_name}"
  
  # Check if the secret exists
  if [ ! -f "$vimcrypt_file" ]; then
    echo "Error: Secret '${secret_name}' not found"
    return 1
  fi

  # Get the password and decrypt
  local vimcrypt_password=$(read_password "Enter the password for the secret")
  local decrypted_text=$(vim_decrypt_file "$vimcrypt_file" "$vimcrypt_password")

  # Create parent directories if they don't exist
  mkdir -p "$(dirname "$output_file")"

  # Write the decrypted content to the file, preserving newlines
  printf "%s" "$decrypted_text" > "$output_file"

  # Check if the write was successful
  if [ $? -eq 0 ]; then
    echo "Secret has been decrypted and saved to $output_file"
    return 0
  else
    echo "Error: Failed to write to $output_file"
    return 1
  fi
}

base32_decode() {
  # Remove any whitespace and convert to uppercase
  local input=$(echo -n "$1" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')

  # Calculate padding if needed
  local padding=$((((8 - ${#input} % 8) % 8)))
  if [ $padding -ne 0 ]; then
    input="${input}$(printf '=%.0s' $(seq 1 ${padding}))"
  fi

  # Decode using base32
  echo -n "${input}" | base32 -d 2>/dev/null
}

totp_secret() {
  local secret_name="$1"
  if [ -z "$1" ]; then
    secret_name=$(cd "${_secretspath}/secrets" && find . -type f -not -path '*/\.*' | sed 's|^\./||' | grep "totp_" | fzf)
    if [ -z "${secret_name}" ]; then
      echo "Empty selection"
      return 1
    fi
  else
    # Allows for shortform, eg. "totp github"
    secret_name="totp_$1"
  fi

  secret=$(get_secret "${secret_name}")

  # Get current time
  local time_step=30
  local epoch=$(date +%s)
  local time_counter=$(($epoch / $time_step))
  local time_hex=$(printf '%016x' $time_counter)

  # Decode the base32 secret and get the full key
  local decoded=$(base32_decode "${secret}")
  local key=$(echo -n "$decoded" | xxd -p -c256)

  # Convert time to binary
  local time_bin=$(echo -n "$time_hex" | xxd -r -p)

  # Calculate HMAC-SHA1
  local hmac=$(echo -n "$time_bin" | \
     openssl dgst -sha1 -mac HMAC -macopt "hexkey:${key}" -binary | \
     xxd -p -c256)

  # Get offset from last byte (& 0xf)
  local offset=$((0x$(echo "$hmac" | tail -c 2) & 0xf))

  # Extract 4 bytes starting at offset
  local dbc=$(echo "$hmac" | cut -b $((offset * 2 + 1))-$((offset * 2 + 8)))

  # Calculate TOTP value
  local otp=$(printf "%d\n" 0x$dbc)
  otp=$((${otp} & 0x7fffffff))
  otp=$((${otp} % 1000000))

  printf "%06d\n" ${otp}
}


_updatesecrets() {
  echo "Branching trees ..."
  cd ${_secretspath}
  git pull

  cd - > /dev/null
}

secrets() {
  if [ $# -lt 1 ]; then
    echo "Usage: $0 <command> [args...]"
    return 1
  fi

  local COMMAND=$1
  shift

  case "$COMMAND" in
    "up" | "update")
      _updatesecrets
      ;;
    "in" | "install")
      _clonesecrets
      ;;
    "get" | "show")
      get_secret $@
      ;;
    "set" | "add")
      add_secret $@
      ;;
    "var")
      var_secret $@
      ;;
    "file" | "out")
      file_secret $@
      ;;
    "totp")
      totp_secret $@
      ;;
    *)
      echo "Unknown command: $0 $COMMAND"
      ;;
  esac
}

if [[ $(secretsini --get "secrets.aliases") == true ]]; then
  alias totp="secrets totp"
fi

