#!/bin/sh
# Build an iocage jail under TrueNAS 13.0 and install Tautulli
# git clone https://github.com/tschettervictor/truenas-iocage-tautulli

# Check for root privileges
if ! [ $(id -u) = 0 ]; then
   echo "This script must be run with root privileges"
   exit 1
fi

#####
#
# General configuration
#
#####

# Initialize defaults
JAIL_IP=""
JAIL_INTERFACES=""
DEFAULT_GW_IP=""
INTERFACE="vnet0"
VNET="on"
POOL_PATH=""
DATA_PATH=""
JAIL_NAME="tautulli"
CONFIG_NAME="tautulli-config"

# Check for tautulli-config and set configuration
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "${SCRIPT}")
if ! [ -e "${SCRIPTPATH}"/"${CONFIG_NAME}" ]; then
  echo "${SCRIPTPATH}/${CONFIG_NAME} must exist."
  exit 1
fi
. "${SCRIPTPATH}"/"${CONFIG_NAME}"
INCLUDES_PATH="${SCRIPTPATH}"/includes

JAILS_MOUNT=$(zfs get -H -o value mountpoint $(iocage get -p)/iocage)
RELEASE=$(freebsd-version | cut -d - -f -1)"-RELEASE"
# If release is 13.1-RELEASE, change to 13.2-RELEASE
if [ "${RELEASE}" = "13.1-RELEASE" ]; then
  RELEASE="13.2-RELEASE"
fi 

#####
#
# Input/Config Sanity checks
#
#####

# Check that necessary variables were set by rslsync-config
if [ -z "${JAIL_IP}" ]; then
  echo 'Configuration error: JAIL_IP must be set'
  exit 1
fi
if [ -z "${JAIL_INTERFACES}" ]; then
  echo 'JAIL_INTERFACES not set, defaulting to: vnet0:bridge0'
  JAIL_INTERFACES="vnet0:bridge0"
fi
if [ -z "${DEFAULT_GW_IP}" ]; then
  echo 'Configuration error: DEFAULT_GW_IP must be set'
  exit 1
fi
if [ -z "${POOL_PATH}" ]; then
  echo 'Configuration error: POOL_PATH must be set'
  exit 1
fi

# If DATA_PATH wasn't set in tautulli-config, set it.
if [ -z "${DATA_PATH}" ]; then
  DATA_PATH="${POOL_PATH}"/tautulli
fi

if [ "${DATA_PATH}" = "${POOL_PATH}" ]
then
  echo "DATA_PATH must be different from POOL_PATH!"
  exit 1
fi

# Extract IP and netmask, sanity check netmask
IP=$(echo ${JAIL_IP} | cut -f1 -d/)
NETMASK=$(echo ${JAIL_IP} | cut -f2 -d/)
if [ "${NETMASK}" = "${IP}" ]
then
  NETMASK="24"
fi
if [ "${NETMASK}" -lt 8 ] || [ "${NETMASK}" -gt 30 ]
then
  NETMASK="24"
fi

#####
#
# Jail Creation
#
#####

# List packages to be auto-installed after jail creation
cat <<__EOF__ >/tmp/pkg.json
	{
  "pkgs":[
  "nano",
  "bash",
  "python",
  "py39-setuptools",
  "py39-sqlite3",
  "py39-openssl",
  "py39-pycryptodomex",
  "ca_root_nss",
  "git-lite"
  ]
}
__EOF__

# Create the jail and install previously listed packages
if ! iocage create --name "${JAIL_NAME}" -p /tmp/pkg.json -r "${RELEASE}" interfaces="${JAIL_INTERFACES}" ip4_addr="${INTERFACE}|${IP}/${NETMASK}" defaultrouter="${DEFAULT_GW_IP}" boot="on" host_hostname="${JAIL_NAME}" vnet="${VNET}"
then
	echo "Failed to create jail"
	exit 1
fi
rm /tmp/pkg.json

#####
#
# Directory Creation and Mounting
#
#####

mkdir -p "${DATA_PATH}"
chown -R 109:109 "${DATA_PATH}"
iocage exec "${JAIL_NAME}" mkdir -p /data
iocage fstab -a "${JAIL_NAME}" "${DATA_PATH}" /data nullfs rw 0 0

#####
#
# Tautulli Installation
#
#####

if ! iocage exec "${JAIL_NAME}" git clone https://github.com/Tautulli/Tautulli.git /usr/local/share/Tautulli
then
	echo "Failed to clone Tautulli"
	exit 1
fi
iocage exec "${JAIL_NAME}" "pw user add tautulli -c tautulli -u 109 -d /nonexistent -s /usr/bin/nologin"
iocage exec "${JAIL_NAME}" chown -R tautulli:tautulli /usr/local/share/Tautulli /data
iocage exec "${JAIL_NAME}" cp /usr/local/share/Tautulli/init-scripts/init.freebsd /usr/local/etc/rc.d/tautulli
iocage exec "${JAIL_NAME}" chmod u+x /usr/local/etc/rc.d/tautulli
iocage exec "${JAIL_NAME}" sysrc tautulli_enable="YES"
iocage exec "${JAIL_NAME}" sysrc tautulli_user=tautulli
iocage exec "${JAIL_NAME}" sysrc "tautulli_flags=--datadir /data"

iocage restart "${JAIL_NAME}"

echo "---------------"
echo "Installation complete."
echo "Visit http://${IP}:8181 to access your Tautulli web interface."
echo "---------------"
