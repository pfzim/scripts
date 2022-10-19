#!/bin/bash

default_host_url='http://brc-influxdb-01.example.org:8086'
default_config_id='06235e123f244400'
default_bucket='linux_general'
default_org='OrgName'
default_token='FLRe-3464c45qu6TjRR24A3543RfEfv0diyr34534dcYdOFal345353NkaJSsdfoxcvx4v-Qz3458_UePxcELH=='
default_package='online'

host_url=''
config_id=''
bucket=''
org=''
token=''
package=''

usage() {
  echo 'Script to install telegraf on Debian'
  echo 'Usage: telegraf_installer.sh -u "http://influxdb.example.org:8086" -c 06964e51d7274800 -b linux_general -o "OrgName" -t "TOKEN_HERE"'
  echo 'Options:'
  echo '  -u|--host-url     - InfluxDB API URL'
  echo '  -c|--config-id    - configuration ID'
  echo '  -b|--bucket       - DB name'
  echo '  -o|--org          - organization name'
  echo '  -t|--token        - token'
  echo '  -p|--package      - deb file name or online'
  echo '  -h|--help         - this help'
}

while [ $# -gt 0 ]; do
  key="$1"

  case $key in
    -u|--host-url)
      host_url="$2"
      shift
      shift
      ;;
    -c|--config-id)
      config_id="$2"
      shift
      shift
      ;;
    -b|--bucket)
      bucket="$2"
      shift
      shift
      ;;
    -o|--org)
      org="$2"
      shift
      shift
      ;;
    -t|--token)
      token="$2"
      shift
      shift
      ;;
    -p|--package)
      package="$2"
      shift
      shift
      ;;
    -h|--help)
      usage
      exit 1
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
    ;;
  esac
done

ask() {
	while :
	do
		read -p "$1" $2
		if [ -n "$(eval echo \"\$$2\")" ] ; then
			break
		fi
		if [ $# -gt 2 -a -n "$3" ] ; then
			eval "$2=\"\$3\""
			break
		fi
	done
}

if [ "$(lsb_release -si)" != "Debian" ]; then
	echo 'This script support only Debian'
	exit 1
fi

if [ -z "${host_url}" ] ; then
	ask "InfluxDB API URL [$default_host_url]: " host_url "$default_host_url"
fi

if [ -z "${config_id}" ] ; then
	ask "Configuration ID [$default_config_id]: " config_id "$default_config_id"
fi

if [ -z "${bucket}" ] ; then
	ask "Bucket [$default_bucket]: " bucket "$default_bucket"
fi

if [ -z "${org}" ] ; then
	ask "Organization name [$default_org]: " org "$default_org"
fi

if [ -z "${token}" ] ; then
	ask "Token [$default_token]: " token "$default_token"
fi

if [ -z "${package}" ] ; then
	ask "DEB package file name [$default_package]: " package "$default_package"
fi

if [ "${package}" = "online" ] ; then
	apt-get update
	apt-get -y install gpg

	wget -qO- https://repos.influxdata.com/influxdb.key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/influxdb.gpg > /dev/null
	export DISTRIB_ID=$(lsb_release -si); export DISTRIB_CODENAME=$(lsb_release -sc)
	echo "deb [signed-by=/etc/apt/trusted.gpg.d/influxdb.gpg] https://repos.influxdata.com/${DISTRIB_ID,,} ${DISTRIB_CODENAME} stable" | tee /etc/apt/sources.list.d/influxdb.list > /dev/null

	apt-get update
	apt-get -y install telegraf
else
	if [ -e "${package}" ] ; then
		dpkg -i "${package}"
	else
		echo "File ${package} not found!"
		exit 1
	fi
fi

sed -i -e "/^\\s*[^#]/ s/^/#/" /etc/default/telegraf

cat >> /etc/default/telegraf <<- EOF
		TELEGRAF_OPTS="-config ${host_url}/api/v2/telegrafs/${config_id}"
		INFLUX_HOST=${host_url}
		INFLUX_TOKEN=${token}
		INFLUX_BUCKET=${bucket}
		INFLUX_ORG=${org}
EOF

[ -d /etc/systemd/system/telegraf.service.d ] || mkdir -p /etc/systemd/system/telegraf.service.d

cat > /etc/systemd/system/telegraf.service.d/override.conf <<- EOF
		[Service]
		ExecStart=
		ExecStart=/usr/bin/telegraf \$TELEGRAF_OPTS
EOF

systemctl daemon-reload
systemctl enable telegraf.service
systemctl restart telegraf.service

echo -e '\e[0;33mInstallation complete. Press Ctrl+C for exit\e[0m'

journalctl -u telegraf -f

exit 0
