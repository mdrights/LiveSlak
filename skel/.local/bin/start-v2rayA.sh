#!/bin/sh

# Try to start Docker daemon first whatever is it running
sudo /etc/rc.d/rc.docker start || true

sleep 5

docker run -d \
  -p 2017:2017 \
  -p 20170-20172:20170-20172 \
  --restart=always \
  --name v2raya \
  -v /etc/v2raya:/etc/v2raya \
  mzz2017/v2raya

sleep 1

xdg-open "http://127.0.0.1:2017"

# Keep this terminal open for a while otherwise Firefox will not open.
# If no browser is opened, please type `localhost:2017` in any browser.
sleep 2

exit
