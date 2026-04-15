#!/bin/bash

source /opt/app-root/etc/generate_container_user

set -e

source ${NGINX_CONTAINER_SCRIPTS_PATH}/common.sh

# disabled, only used to source nginx files in user directory
#process_extending_files ${NGINX_APP_ROOT}/src/nginx-start ${NGINX_CONTAINER_SCRIPTS_PATH}/nginx-start

if [ ! -v NGINX_LOG_TO_VOLUME -a -v NGINX_LOG_PATH ]; then
    /bin/ln -sf /dev/stdout ${NGINX_LOG_PATH}/access.log
    /bin/ln -sf /dev/stderr ${NGINX_LOG_PATH}/error.log
fi

# substitute NB_PREFIX in proxy configuration if it exists
if [ -z "$NB_PREFIX" ]; then
    cp /opt/app-root/etc/nginx.default.d/proxy.conf.template /opt/app-root/etc/nginx.default.d/proxy.conf
else
    export BASE_URL=$(echo $NB_PREFIX | awk -F/ '{ print $4"-"$3 }')$(echo $NOTEBOOK_ARGS | grep -Po 'hub_host":"\K.*?(?=")' | awk -F/ '{ print $3 }' | awk -F. '{for (i=2; i<=NF; i++) printf ".%s", $i}')
    envsubst '${NB_PREFIX},${BASE_URL}' < /opt/app-root/etc/nginx.default.d/proxy.conf.template_nbprefix > /opt/app-root/etc/nginx.default.d/proxy.conf

    # A temp file is used because piping envsubst directly into the same file via `tee`
    # is a race condition: `tee` can truncate the file before `envsubst` finishes reading it,
    # resulting in an empty/corrupt config and "no events section" errors from nginx.
    tmp=$(mktemp)
    envsubst '${BASE_URL}' < /etc/nginx/nginx.conf > "$tmp"
    cat "$tmp" > /etc/nginx/nginx.conf
    rm -f "$tmp"
fi

nginx