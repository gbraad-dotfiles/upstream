netcheck() {
  ping -c 3 8.8.8.8 > /dev/null 2>&1
  if [ $? -ne 0 ]; then
     echo 'Network [Failed]'
     exit 1
  fi
  echo 'Network [  OK  ]'
}

externalip() {
  curl -fsSL https://ifconfig.co/ip
}

country() {
  curl -fsSL https://ifconfig.co/json | jq -r '.country'
}
