#!/bin/bash

###credit: http://verbally.flimzy.com/install-couchdb-1-6-1-debian-8-2-jessie/

##add sources to apt
echo "deb http://packages.erlang-solutions.com/debian jessie contrib" > /etc/apt/sources.list.d/erlang-solutions.list

##get repository key
wget -qO - http://packages.erlang-solutions.com/debian/erlang_solutions.asc | apt-key add -

##update using new source
apt-get update

##instal dependancies
apt-get --no-install-recommends -y install build-essential pkg-config erlang libicu-dev libmozjs185-dev libcurl4-openssl-dev curl

##get specific erlang-dependancies or else couchdb won't work
apt-get -y install erlang-dev=1:17.5.3 erlang-base=1:17.5.3 erlang-crypto=1:17.5.3 \
                      erlang-nox=1:17.5.3 erlang-inviso=1:17.5.3 erlang-runtime-tools=1:17.5.3 \
                      erlang-inets=1:17.5.3 erlang-edoc=1:17.5.3 erlang-syntax-tools=1:17.5.3 \
                      erlang-xmerl=1:17.5.3 erlang-corba=1:17.5.3 erlang-mnesia=1:17.5.3 \
                      erlang-os-mon=1:17.5.3 erlang-snmp=1:17.5.3 erlang-ssl=1:17.5.3 \
                      erlang-public-key=1:17.5.3 erlang-asn1=1:17.5.3 erlang-ssh=1:17.5.3 \
                      erlang-erl-docgen=1:17.5.3 erlang-percept=1:17.5.3 erlang-diameter=1:17.5.3 \
                      erlang-webtool=1:17.5.3 erlang-eldap=1:17.5.3 erlang-tools=1:17.5.3 \
                      erlang-eunit=1:17.5.3 erlang-ic=1:17.5.3 erlang-odbc=1:17.5.3 \
                      erlang-parsetools=1:17.5.3

##fix version into place (no updates)
apt-mark hold erlang-dev erlang-base erlang-crypto erlang-nox erlang-inviso erlang-runtime-tools \
                      erlang-inets erlang-edoc erlang-syntax-tools erlang-xmerl erlang-corba \
                      erlang-mnesia erlang-os-mon erlang-snmp erlang-ssl erlang-public-key \
                      erlang-asn1 erlang-ssh erlang-erl-docgen erlang-percept erlang-diameter \
                      erlang-webtool erlang-eldap erlang-tools erlang-eunit erlang-ic erlang-odbc \
                      erlang-parsetools

##setup environment
useradd -d /var/lib/couchdb couchdb
mkdir -p /usr/local/{lib,etc}/couchdb /usr/local/var/{lib,log,run}/couchdb /var/lib/couchdb
chown -R couchdb:couchdb /usr/local/{lib,etc}/couchdb /usr/local/var/{lib,log,run}/couchdb
chmod -R g+rw /usr/local/{lib,etc}/couchdb /usr/local/var/{lib,log,run}/couchdb

##download
LINK=$(curl -s "https://www.apache.org/dyn/closer.lua?path=/couchdb/source/1.6.1/apache-couchdb-1.6.1.tar.gz" | grep -i -A 2 "<p> We suggest the following mirror" | sed -n -e 's/.*<strong>\(.*\)<\/strong>.*/\1/p' 2> /dev/null)

if [[ -z ${LINK+x} ]] || [[ -z $LINK ]]; then
	echo -e "\nCould not find link to download couchdb sources\nCheck your internet connection and try again later\n\n\tExiting"
	exit
fi

wget "$LINK"

##check authenticity using hashes
echo -e "\nChecking md5 hash"
if [[ $(md5sum apache-couchdb-1.6.1.tar.gz) == '01a2c8ab4fcde457529428993901a060  apache-couchdb-1.6.1.tar.gz' ]]; then
	echo -e "\n\t\033[0;32mMD5 OK\033[0m\n"
else
	echo -e "\n\t\033[0;31mMD5 doesn't match\033[0m\n\tDeleting apache-couchdb-1.6.1.tar.gz"
	rm -f apache-couchdb-1.6.1.tar.gz
	if [[ ! -f apache-couchdb-1.6.1.tar.gz ]]; then
		echo -e "\n\t\033[0;32mapache-couchdb-1.6.1.tar.gz removed succesfully\033[0m\n"
	else
		echo -e "\n\t\033[0;31m!!!apache-couchdb-1.6.1.tar.gz couldn't be removed!!!\033[0m\n"
	fi
	exit
fi

echo -e "\nChecking sha1 hash"
if [[ $(sha1sum apache-couchdb-1.6.1.tar.gz) == '6275f3818579d7b307052e9735c42a8a64313229  apache-couchdb-1.6.1.tar.gz' ]]; then
	echo -e "\n\t\033[0;32mSHA1 OK\033[0m\n"
else
	echo -e "\n\t\033[0;31mSHA1 doesn't match\033[0m\n\tDeleting apache-couchdb-1.6.1.tar.gz"
	rm -f apache-couchdb-1.6.1.tar.gz
	if [[ ! -f apache-couchdb-1.6.1.tar.gz ]]; then
		echo -e "\n\t\033[0;32mapache-couchdb-1.6.1.tar.gz removed succesfully\033[0m\n"
	else
		echo -e "\n\t\033[0;31m!!!apache-couchdb-1.6.1.tar.gz couldn't be removed!!!\033[0m\n"
	fi
	exit
fi

##compile and install
tar xzf apache-couchdb-1.6.1.tar.gz
cd apache-couchdb-1.6.1
./configure --prefix=/usr/local --with-js-lib=/usr/lib --with-js-include=/usr/include/js --enable-init
make && make install

##finish setup
chown couchdb:couchdb /usr/local/etc/couchdb/local.ini
ln -s /usr/local/etc/init.d/couchdb /etc/init.d/couchdb
ln -s /usr/local/etc/couchdb /etc
update-rc.d couchdb defaults
/etc/init.d/couchdb start

##verification
echo -e "\nChecking couchdb status..."
COUCH=$(curl -s 127.0.0.1:5984 2> /dev/null)
Y=0
while [[ -z ${COUCH+x} || -z $COUCH ]] && (( $Y < 40 )); do
	COUCH=$(curl -s 127.0.0.1:5984 2> /dev/null)
	Y=$(($Y+1))
	sleep 1
done
if [[ $COUCH == *'{"couchdb":"Welcome"'*'"vendor":{"name":"The Apache Software Foundation","version":"1.6.1'* ]]; then
	echo -e "\n\t\033[0;32mALL OK\033[0m\n"
else
	echo -e "\n\t\033[0;31mSmth went wrong\033[0m\n"
fi
echo -e "Curl result: $COUCH\n"

read -p "Make couchdb available to the outside? [y/N]: " y
if [[ $y == 'y' ]]; then
#################can be done from http://127.0.0.1:5984/_utils in Configuration#####
	##use sed to make couchdb available to the outside
	sed -i -e 's/;*bind_address =.*/bind_address = 0.0.0.0 /' /etc/couchdb/local.ini

	##restart couch
	/etc/init.d/couchdb restart
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
