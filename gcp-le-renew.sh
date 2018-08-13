#!/bin/sh

# Restore working dir into /etc/letsencrypt/
tar -zxf /workspace/letsencrypt.tar.gz --directory /etc/letsencrypt/

# Run the certbot
certbot "$@"

# Backup into working dir
tar -zcf /workspace/letsencrypt.tar.gz --directory /etc/letsencrypt/ .
