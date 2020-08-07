# superprueba

# People Improvement Cambodia - Samba Server/Client Setup Documentation

Scripts and documentation used to manage Samba Server (based on Zentyal 6.0 Devel). It helps adding and removing users for the roaming users using Raspberry Pi clients.

## Client Configuration

All information listed here is valid as refererence because is already done by cloning Raspberry Pi micro SD cards: 

1. Make sure client is on time `systemctl restart systemd-timesyncd`
2. `apt-get update; apt-get install -y libnss-ldapd nslcd libpam-ldapd openssl nscd libpam-mount  winbind smbclient cifs-utils`
3. Add this information to the assistant: 
- LDAP server Uniform Resource Identifier: `ldap://192.168.0.2:389`
- Distinguished name of the search base: `dc=pio,dc=local`
- LDAP version: `3`
- Make local root Database admin: `<No>`
- Does the LDAP database require login?  `<No>`
4. Finish `ldap.conf` configuration file for clients:
- `rm /etc/ldap/ldap.conf`
- `ln -s /etc/ldap.conf /etc/ldap/ldap.conf`
- Edit `/etc/ldap.conf` and make sure it has this configuration:
```
base dc=pio,dc=local

uri ldap://192.168.0.2:389

ldap_version 3

pam_password md5

binddn CN=Administrator,CN=Users,DC=pio,DC=local
bindpw YOURPASS

scope sub
bind_policy soft
pam_password md5

nss_base_passwd         CN=Users,DC=pio,DC=local?one
nss_base_passwd         CN=Computers,DC=pio,DC=local?one
nss_base_shadow         CN=Users,DC=pio,DC=local?one
nss_base_group          CN=Groups,DC=pio,DC=local?one
nss_schema              rfc2307bis
nss_map_attribute uniqueMember member
nss_reconnect_tries 2
nss_initgroups_ignoreusers avahi,avahi-autoipd,backup,bin,colord,daemon,games,gnats,hplip,irc,kernoops,libuuid,lightdm,list,lp,mail,man,messagebus,news,proxy,pulse,root,rtkit,saned,speech-dispatcher,sshd,sync,sys,syslog,usbmux,uucp,whoopsie,www-data,pi
```
5. in /etc/nslcd.conf
```
uid nslcd
gid nslcd

base dc=pio,dc=local

uri ldap://192.168.0.2:389

ldap_version 3

binddn CN=Administrator,CN=Users,DC=pio,DC=local
bindpw passwordhere

scope sub
```
6. Enable services:
```
systemctl enable nslcd
systemctl restart nslcd
systemctl enable nscd
systemctl restart nscd
```
7. To test configuration:
- `ldapsearch -D "uid=testuser,CN=Users,DC=pio,DC=local" -LLL -W uid=testuser` Or any existing user
- `ldapsearch -x -h 192.168.0.2 -p 389 -D "cn=Administrator,cn=Users,dc=pio,dc=local" -b "cn=Users,dc=pio,dc=local" -W`
8. Switch system auth to allow ldap on the authentication chain:
`auth-client-config -t nss -p lac_ldap`
9. Typing `id testuser` (being testuser a Samba/LDAP user) should show valid UID and GID
10. Configure system for automount home folders in file `/etc/security/pam_mount.conf.xml` add thsi in the volumes section:
```
<volume user="*" fstype="cifs" server="192.168.0.2" path="%(USER)" mountpoint="/home/%(USER)" options="workgroup=WORKGROUP,uid=%(USER),dir_mode=0700,file_mode=0700,nosuid,nodev" />
```
11. Also we need to make sure home dirs are created on server if they don't exist (first timers) at `/etc/pam.d/common-session`:
```
session required        pam_unix.so
session optional        pam_mount.so
session optional        pam_ldap.so
session optional        pam_systemd.so
session required        pam_mkhomedir.so skel=/etc/skel/ umask=0077
```


## Users Management

There is a script called `pio-tool` in `/usr/local/bin/pio-tool`, that code is also in this repository.

*REQUIRED* It is required to be in the wifi network called 'Temple Wifi' then SSH to the samba server `192.168.0.2`

- List existing users:
`sudo pio-tool -l`

- Create user:
`sudo pio-tool -a USERNAME -p PASSWORD`

- Delete user:
`sudo pio-tool -d USERNAME`

- Change user password: 
`sudo pio-tool -p USERNAME`

- Bulk provisioning:

Create a text file called list with format as follows, values separated by a space:
```
username1 password
username2 password
username3 password
```

Then run this one-liner script:
`while read user pass; do sudo pio-tool -a $user -p $pass; done < list`

## Cloning micro SD cards with dd on MAC OS and showing progress:

`dd if=raspbian_backup.img | pv -s 32G |dd of=/dev/disk3`

`pv` command has to be installed on the system, probably you don't have it so install it with `brew install pv`.
