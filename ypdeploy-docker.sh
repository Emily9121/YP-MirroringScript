#!/bin/bash

#If you have multiple domains, you'll need to stop nginx and extand your SSL certificate!
#using ./letsencrypt-auto certonly -n --agree-tos --standalone -d domain1.com -d domain2.com ... -m yourmail@address.com --expand
#in /opt/yayponies/letsencrypt


SYSTEM=debian
VERSION=jessie
DOMAIN=$1
MAIL=$2
KERNEL=$(uname -s)

case "$KERNEL" in
	Linux)
	;;
	Darwin)
	echo "Your server is bad and you should feel bad."
	exit 1
	;;
	*)
	echo "What the buck is your operating system?!"
	exit 1
	;;
esac

if [[ -z $1 && -z $2 ]]; then
echo "usage: ./yayponies-deploy.sh domain.com yourmail@address.com [--nossl]"
echo "--nossl should be the third argument"
exit
fi

if [ $1 = "--nossl" ]; then
echo "usage: ./yayponies-deploy.sh domain.com yourmail@address.com [--nossl]"
echo "--nossl should be the third argument"
exit
fi

if [ $2 = "--nossl" ]; then
echo "usage: ./yayponies-deploy.sh domain.com yourmail@address.com [--nossl]"
echo "--nossl should be the third argument"
exit
fi

if [ $3 = "--nossl" ]; then
SSL=nnope
fi

echo "Deploying YayPonies Mirror"
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo "This script has only been tested on Debian Jessie"
echo "It will install a new mirror on a newly deployed system"
echo "It SHOULD NOT BE USED ON MULTIPLE SITE CONFIGURATION"
echo "IT SHOULD ALSO NOT BE USED IF PORT 80 IS UNAVAILABLE"
echo ""
echo "This will add docker repository, install docker"
echo "pull official nginx, prepare configuration"
echo "and start it, please read the script before usage"
echo ""
echo "This program is distributed WITHOUT ANY WARRANTY"
read -n1 -r -p "Press space or enter to continue, any other keys to cancel..." key

if [ "$key" = '' ]; then
    echo ""
    echo "OK, Starting..."
else
    echo ""
    echo "OK, Cancelling..."
    exit 1
fi

apt-get purge lxc-docker*
apt-get purge docker.io*
apt-get update
apt-get install apt-transport-https ca-certificates
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
touch /etc/apt/sources.list.d/docker.list
echo "deb https://apt.dockerproject.org/repo $SYSTEM-$VERSION main" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-cache policy docker-engine
apt-get update
apt-get install docker-engine
service docker start
docker pull nginx
mkdir -p /opt/yayponies/nginx
mkdir -p /opt/yayponies/site
cd /opt/yayponies/site
apt-get install git cron
git clone https://git.yayponies.pw/ypmirror.git .
cd /opt/yayponies/nginx
touch yayponies-http.conf
HTTP="    server {\n
        listen       80 default_server;\n
        listen       [::]:80 default_server;\n
        server_name  $DOMAIN;\n
        ssi on;\n
        root         /srv/http;\n
        error_page 404 /sorry/404.php;\n
        error_page 403 /sorry/403.php;\n
        autoindex off;\n
        location / {\n
                index index.php index.html index.htm;\n
                error_page 404 /sorry/404.php;\n
                error_page 403 /sorry/403.php;\n
        }\n
        location ~ \.php$ {\n
                types { text/html php; }\n
        }       \n
    }"
echo -e $HTTP > yayponies-http.conf
if [ "$SSL" != "nnope" ]; then
	mkdir -p /opt/yayponies/letsencrypt
	cd /opt/yayponies/letsencrypt
	git clone https://github.com/letsencrypt/letsencrypt .
	./letsencrypt-auto
	./letsencrypt-auto certonly -n --agree-tos --standalone -d $DOMAIN -m $MAIL
	cd /opt/yayponies/nginx
	touch yayponies-https.conf
	HTTPS="    server {\n
	        listen       443 ssl;\n
	        listen       [::]:443 ssl;\n
	        server_name  $DOMAIN;\n
	        ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;\n
	        ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;\n
	        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;\n
	        ssl_prefer_server_ciphers on;\n
	        ssl_ciphers 'EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH';\n
	        ssl_dhparam /etc/ssl/private/dhparams.pem;\n
	\n
	        ssi on;\n
	        root         /srv/http;\n
	        error_page 404 /sorry/404.php;\n
	        error_page 403 /sorry/403.php;\n
	        autoindex off;\n
	        location / {\n
	                index index.php index.html index.htm;\n
	                error_page 404 /sorry/404.php;\n
	                error_page 403 /sorry/403.php;\n
	        }\n
	        location ~ \.php$ {\n
	                types { text/html php; }\n
	        }       \n
	    }"
	echo -e $HTTPS > yayponies-https.conf
	mkdir -p /etc/ssl/private
	chmod 710 /etc/ssl/private
	cd /etc/ssl/private
	openssl dhparam -out dhparams.pem 2048
	docker run --name yayponies -v /opt/yayponies/nginx:/etc/nginx/conf.d:ro -v /etc/letsencrypt:/etc/letsencrypt:ro -v /etc/ssl/private:/etc/ssl/private:ro -v /opt/yayponies/site:/srv/http:ro -p 80:80 -p 443:443 -d nginx
fi
if [ "$SSL" = "nnope" ]; then
	docker run --name yayponies -v /opt/yayponies/nginx:/etc/nginx/conf.d:ro -v /opt/yayponies/site:/srv/http:ro -p 80:80 -d nginx
fi
echo "Your YayPonies Mirror is now live at $DOMAIN"
echo "Setting up YayPonies cron"
echo "Default: Update the mirror every 10 minutes"
CRON="#!/bin/bash\n
     cd /opt/yayponies/site\n
     git pull\n
	 docker start yayponies"
touch /usr/bin/yayponies-update.sh
echo -e $CRON > /usr/bin/yayponies-update.sh
chmod 755 /usr/bin/yayponies-update.sh
crontab -l > /tmp/yayponies-cron
echo "*/10 * * * * /usr/bin/yayponies-update.sh" >> /tmp/yayponies-cron
crontab /tmp/yayponies-cron
rm /tmp/yayponies-cron
if [ "$SSL" != "nnope" ]; then
	echo "Setting up Cron for LetsEncrypt SSL certificate"
	echo "Default: Renew certificate every month"
	CRONSSL="#!/bin/bash\n
     		docker stop yayponies\n
		cd /opt/yayponies/letsencrypt\n
		./letsencrypt-auto renew\n
		docker start yayponies"
	touch /usr/bin/yayssl-update.sh
	echo -e $CRONSSL > /usr/bin/yayssl-update.sh
	chmod 755 /usr/bin/yayssl-update.sh
	crontab -l > /tmp/ssl-cron
	echo "0 0 1 * * /usr/bin/yayssl-update.sh" >> /tmp/ssl-cron
	crontab /tmp/ssl-cron
	rm /tmp/ssl-cron
fi

