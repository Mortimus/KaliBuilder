# Kali ISO Building

This is a tool to help build a custom Kali Linux ISO to deploy to clients for authorized remote access to penetration testing tools to perform Evil-Maid type assessments

## Process

### Create VPN Profile

Create an OpenVPN profile and move it to the build machine

#### Move CLIENTNAME.ovpn to the ISO build machine

```bash
scp CLIENTNAME.ovpn kali@BUILDBOX:~/
```

### Clone the repo

```bash
cd ~ # Move to Home folder
git clone git@github.com:Mortimus/KaliBuilder.git
cd KaliBuilder
```

### Build ISO

```shell
# Build an iso for the client for CLIENTNAME.ovpn
./Build_ISO.sh CLIENTNAME.ovpn
```

* "CLIENTNAME.ovpn" is the client ovpn file
* "/home/kali/KaliBuilder/variant-mycompany" is the folder from this repo containing the base config (optional)

## Changes from standard Kali

```txt
pipx tools - set to global so all users (including root) can use `pipx list --global
golang tools
various installerless tools
nxc sensible config
ssh keys for each engineer
auto security updates
tmux logging to ~/Logs
tmux mouse on
tmux sensible
unique user for each engineer
breakglass account
mycompany account
sudo no password
updated bash history settings
colorized nmap
added `whatismyip` alias to check public ip
```

## Structure

```txt
variant-mycompany
├── bootloaders
│   ├── grub-pc
│   │   └── theme
│   └── syslinux_common
├── hooks
│   └── normal                        # Place bash scripts here for pre-install configs
├── includes.binary
│   └── isolinux
├── includes.chroot                   # This allows us to place files on the raw filesystem
│   ├── etc
│   │   ├── openvpn                   # client.conf auto connect profile
│   │   └── ssh                       # Sudo NOPASSWD
│   ├── opt
│   │   ├── mycompany
│   │   │   └── virtual               # Non-pipx tools
│   │   │       └── installers        # Non-pipx installers
│   │   └── nessus
│   │       └── lib
│   │           └── nessus
│   │               └── plugins       # XML plugin
│   └── root                          # Guaranteed path, put files here and use hooks to copy to other users if needed
│       ├── .nxc                      # NetExec config to copy to all users
│       └── .ssh                      # ssh keys to copy to all users
├── includes.installer                # Has preseed
├── package-lists                     # Contains what apt packages to install
└── packages.chroot                   # deb files to install must be $PACKAGENAME_$VERSION_$ARCH.deb format
```
