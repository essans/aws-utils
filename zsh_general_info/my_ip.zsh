# Get current public IPv4

function my_ip() {

  echo " "

  local MY_IP
  MY_IP="$(curl -s https://checkip.amazonaws.com | tr -d '\n')/32"

  echo "👉 my ip address is 🌐 $MY_IP"
  echo " "
}

