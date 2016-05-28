# YP-MirroringScript
Help you mirror YP from a scratch Debian Jessie install

It take either two or three argument, example

ypdeploy-native.sh mymirrorurl.com mymail@address.com
or
ypdeploy-native.sh mymirrorurl.com mymail@address.com --nossl

without --nossl, it will create a new certificate from LetsEncrypt for the domain you set up and configure it to be renewed every month

It's planned to be used on FRESH install, the native version will delete default nginx config (in /etc/nginx/sites-enabled/default), use at your own risk!
For the docker version: You don't need to install docker, we install it for you, also, the git update also ask docker to start the container, so after a reboot
you might have to wait 10 minutes for the next git update to happen before the service being started up.
