#!/usr/bin/env bash

# Load bash libraries
SCRIPT_DIR=$(dirname -- "$0")
source ${SCRIPT_DIR}/utils/*.sh

# Start nginx and supervisord
run-nginx.sh &
/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf &


# Add .bashrc for custom promt if not present
if [ ! -f "/opt/app-root/src/.bashrc" ]; then
  echo 'PS1="\[\033[34;1m\][\$(pwd)]\[\033[0m\]\n\[\033[1;0m\]$ \[\033[0m\]"' > /opt/app-root/src/.bashrc
fi

# Create lib folders if it does not exist
mkdir -p  /opt/app-root/src/Rpackages/4.3
for package in /opt/app-root/bin/Rpackages/4.3/*/;
do
  package_folder=$(basename "$package")
  if [ ! -d "/opt/app-root/src/Rpackages/4.3/$package_folder" ]; then
    cp -r /opt/app-root/bin/Rpackages/4.3/$package_folder /opt/app-root/src/Rpackages/4.3/
  fi
done  
# rstudio terminal cant see environment variables set by the container runtime
# (which breaks kubectl, to fix this we store the KUBERNETES_* env vars in Renviron.site)
env | grep KUBERNETES_ >> /usr/lib64/R/etc/Renviron.site

export USER=$(whoami)

# Initilize access logs for culling
echo '[{"id":"rstudio","name":"rstudio","last_activity":"'$(date -Iseconds)'","execution_state":"running","connections":1}]' > /var/log/nginx/rstudio.access.log

# Create RStudio launch command
launch_command=$(python /opt/app-root/bin/setup_rstudio.py)

echo $launch_command

start_process $launch_command
