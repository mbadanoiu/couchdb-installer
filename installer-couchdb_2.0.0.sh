#!/bin/bash

#credit: https://github.com/ixtisgit/couchdb-debian-install/blob/master/couchdb-install

##update and install dependancies
apt-get update || true
apt-get --no-install-recommends -y install \
    build-essential pkg-config runit erlang \
    libicu-dev libmozjs185-dev libcurl4-openssl-dev curl

##downloading source
LINK=$(curl -s "https://www.apache.org/dyn/closer.lua?path=/couchdb/source/2.0.0/apache-couchdb-2.0.0.tar.gz" | grep -i -A 2 "<p> We suggest the following mirror" | sed -n -e 's/.*<strong>\(.*\)<\/strong>.*/\1/p' 2> /dev/null)

if [[ -z ${LINK+x} ]] || [[ -z $LINK ]]; then
	echo -e "\nCould not find link to download couchdb sources\nCheck your internet connection and try again later\n\n\tExiting"
	exit
fi

wget "$LINK"

##check authenticity using hashes
echo -e "\nChecking md5 hash"
if [[ $(md5sum apache-couchdb-2.0.0.tar.gz) == '402fc02df28a5297a56cedebbae42524  apache-couchdb-2.0.0.tar.gz' ]]; then
	echo -e "\n\t\033[0;32mMD5 OK\033[0m\n"
else
	echo -e "\n\t\033[0;31mMD5 doesn't match\033[0m\n\tDeleting apache-couchdb-2.0.0.tar.gz"
	rm -f apache-couchdb-2.0.0.tar.gz
	if [[ ! -f apache-couchdb-2.0.0.tar.gz ]]; then
		echo -e "\n\t\033[0;32mapache-couchdb-2.0.0.tar.gz removed succesfully\033[0m\n"
	else
		echo -e "\n\t\033[0;31m!!!apache-couchdb-2.0.0.tar.gz couldn't be removed!!!\033[0m\n"
	fi
	exit
fi

echo -e "\nChecking sha1 hash"
if [[ $(sha1sum apache-couchdb-2.0.0.tar.gz) == 'ea59ff4be4550acdf5fd75e4b83d3e67dea38fd9  apache-couchdb-2.0.0.tar.gz' ]]; then
	echo -e "\n\t\033[0;32mSHA1 OK\033[0m\n"
else
	echo -e "\n\t\033[0;31mSHA1 doesn't match\033[0m\n\tDeleting apache-couchdb-2.0.0.tar.gz"
	rm -f apache-couchdb-2.0.0.tar.gz
	if [[ ! -f apache-couchdb-2.0.0.tar.gz ]]; then
		echo -e "\n\t\033[0;32mapache-couchdb-2.0.0.tar.gz removed succesfully\033[0m\n"
	else
		echo -e "\n\t\033[0;31m!!!apache-couchdb-2.0.0.tar.gz couldn't be removed!!!\033[0m\n"
	fi
	exit
fi

echo -e "\nChecking sha256 hash"
if [[ $(sha256sum apache-couchdb-2.0.0.tar.gz) == 'ccaf3ce9cb06c50a73e091696e557e2a57c5ba02c5b299e1ac2f5b959ee96eca  apache-couchdb-2.0.0.tar.gz' ]]; then
	echo -e "\n\t\033[0;32mSHA256 OK\033[0m\n"
else
	echo -e "\n\t\033[0;31mSHA256 doesn't match\033[0m\n\tDeleting apache-couchdb-2.0.0.tar.gz"
	rm -f apache-couchdb-2.0.0.tar.gz
	if [[ ! -f apache-couchdb-2.0.0.tar.gz ]]; then
		echo -e "\n\t\033[0;32mapache-couchdb-2.0.0.tar.gz removed succesfully\033[0m\n"
	else
		echo -e "\n\t\033[0;31m!!!apache-couchdb-2.0.0.tar.gz couldn't be removed!!!\033[0m\n"
	fi
	exit
fi

##extract, configure and make
tar -xvzf apache-couchdb-2.0.0.tar.gz
cd apache-couchdb-2.0.0/
./configure && make release

##setup environment
adduser --system \
        --no-create-home \
        --shell /bin/bash \
        --group --gecos \
        "CouchDB Administrator" couchdb

cp -R rel/couchdb /etc/couchdb
chown -R couchdb:couchdb /etc/couchdb
find /etc/couchdb -type d -exec chmod 0770 {} \;
sh -c 'chmod 0644 /etc/couchdb/etc/*'

cat <<EOT >> /etc/systemd/system/couchdb.service
[Unit]
Description=Couchdb service
After=network.target
[Service]
User=couchdb
ExecStart=/etc/couchdb/bin/couchdb -o /dev/stdout -e /dev/stderr
Restart=always
[Install]
WantedBy=multi-user.target
EOT

systemctl daemon-reload
systemctl start couchdb
systemctl enable couchdb

##verification
echo -e "\nChecking couchdb status..."
COUCH=$(curl -s 127.0.0.1:5984 2> /dev/null)
Y=0
while [[ -z ${COUCH+x} || -z $COUCH ]] && (( $Y < 40 )); do
	COUCH=$(curl -s 127.0.0.1:5984 2> /dev/null)
	Y=$(($Y+1))
	sleep 1
done
if [[ $COUCH == *'{"couchdb":"Welcome","version":"2.0.0","vendor":{"name":"The Apache Software Foundation"}}'* ]]; then
	echo -e "\n\t\033[0;32mALL OK\033[0m\n"
else
	echo -e "\n\t\033[0;31mSmth went wrong\033[0m\n"
fi
echo -e "Curl result: $COUCH\n"

read -p "Make couchdb available to the outside? [y/N]: " y
if [[ $y == 'y' ]]; then
#################can be done from http://127.0.0.1:5984/_utils in Configuration#####
	##use sed to make couchdb available to the outside
	sed -i -e 's/;*bind_address =.*/bind_address = 0.0.0.0 /' /etc/couchdb/etc/local.ini

	##restart couch
	systemctl restart couchdb
####################################################################################
fi

##final touch
VM_IPS=($(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*'))
if [[ ${#VM_IPS[@]} = 1 ]]; then
	SITES="http://${VM_IPS[0]}:5984/_utils/"
else
	for i in ${VM_IPS[@]}; do
		SITES="$SITES\n\tor\nhttp://$i:5984/_utils/"
	done
	SITES=${SITES:8}
fi
echo -e "\nNow go to:\n$SITES\n\tand follow: http://guide.couchdb.org/draft/security.html"
