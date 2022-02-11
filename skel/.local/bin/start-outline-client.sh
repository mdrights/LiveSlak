#!/bin/sh

# Try to start Proxy Controller daemon whatever is it running
sudo /etc/rc.d/rc.outline-proxy-controller start || true

sleep 3

/opt/outline-client/Outline-Client.AppImage

sleep 2
