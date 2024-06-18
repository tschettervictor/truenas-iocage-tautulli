# truenas-iocage-tautulli
Script to create an iocage jail on TrueNAS and install Tautulli

This script will create an iocage jail on TrueNAS CORE 13.0 and install Tautulli. It will configure the jail to store the data outside the jail, so it will not be lost in the event you need to rebuild the jail.

## Status
This script will work with TrueNAS CORE 13.0.  Due to the EOL status of FreeBSD 12.0, it is unlikely to work reliably with earlier releases of FreeNAS.

## Usage

### Prerequisites (Other)
You will need to create 
- 1 Dataset named `tautulli` which will store the data.
If this is not present, a directory `/tautulli` will be created in `$POOL_PATH` You will want to create the dataset, otherwise the directory will just be created. Datasets make it easy to do snapshots etc...
e.g. `/mnt/mypool/apps/tautulli`

### Installation
Download the repository to a convenient directory on your TrueNAS system by changing to that directory and running `git clone https://github.com/tschettervictor/truenas-iocage-tautulli`.  Then change into the new `truenas-iocage-tautulli` directory and create a file called `tautulli-config` with your favorite text editor.  In its minimal form, it would look like this:
```
JAIL_IP="192.168.1.199"
DEFAULT_GW_IP="192.168.1.1"
POOL_PATH="/mnt/tank/apps"
```
Many of the options are self-explanatory, and all should be adjusted to suit your needs, but only a few are mandatory.  The mandatory options are:

* JAIL_IP is the IP address for your jail.  You can optionally add the netmask in CIDR notation (e.g., 192.168.1.199/24).  If not specified, the netmask defaults to 24 bits.  Values of less than 8 bits or more than 30 bits are invalid.
* DEFAULT_GW_IP is the address for your default gateway
* POOL_PATH is the path where the script will create the `tautulli` folder if the `tautulli` dataset was not created. It is best to create a dataset inside this path called `tautulli`.
 
In addition, there are some other options which have sensible defaults, but can be adjusted if needed.  These are:

* JAIL_NAME: The name of the jail, defaults to "tautulli"
* DATA_PATH. This is the path to your database files. It defaults to POOL_PATH/tautulli
* INTERFACE: The network interface to use for the jail.  Defaults to `vnet0`.
* JAIL_INTERFACES: Defaults to `vnet0:bridge0`, but you can use this option to select a different network bridge if desired.  This is an advanced option; you're on your own here.
* VNET: Whether to use the iocage virtual network stack.  Defaults to `on`.
* CERT_EMAIL is the email address Let's Encrypt will use to notify you of certificate expiration, or for occasional other important matters.  This is optional.  If you **are** using Let's Encrypt, though, it should be set to a valid address for the system admin.

### Execution
Once you've downloaded the script and prepared the configuration file, run this script (`script tautulli.log ./tautulli-jail.sh`).  The script will run for several minutes.  When it finishes, your jail will be created, Tautulli will be installed, and you can access it at your jail IP on port 8181.

### Notes
- Reinstalls should just work and pick up your previous data
- Tautulli runs on port 8181
