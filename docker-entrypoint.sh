#!/bin/bash


# Exit on any script failures
set -e -o pipefail


# Ensure the ppp device exists
[[ -c /dev/ppp ]] || su-exec root mknod /dev/ppp c 108 0

# Do not run haproxy without REMOTE_ADDRS
if [[ ! -n "${REMOTE_ADDRS}" ]]; then
  echo "Environment variable REMOTE_ADDRS is not set."
else
  # Tweak haproxy config
  REMOTE_ADDRS=(${REMOTE_ADDRS// /})
  IFS=,
  REMOTE_ADDRS=(${REMOTE_ADDRS})

  COUNTER=1
  for REMOTE_ADDR in "${REMOTE_ADDRS[@]}"; do 
    echo $REMOTE_ADDR
    Q=(${REMOTE_ADDR//->/,})
    LOCALPORT=(${Q[0]})
    REMOTE=(${Q[1]})
    cat <<- EOF >> /etc/haproxy/haproxy.cfg
frontend fr_server$COUNTER
    bind 0.0.0.0:$LOCALPORT
    default_backend bk_server$COUNTER
backend bk_server$COUNTER
    server srv1 $REMOTE maxconn 2048
EOF
    COUNTER=`expr $COUNTER + 1`
  done

  # Run haproxy daemon
  exec su-exec root haproxy -f /etc/haproxy/haproxy.cfg &
fi


# Force all args into openfortivpn
if [[ "$1" = 'openfortivpn' ]]; then
  shift
fi

exec openfortivpn "$@"
