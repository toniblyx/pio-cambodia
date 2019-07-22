# People Improvement Cambodia stuff

Scripts and documentation used to manage Samba Server (based on Zentyal 6.0 Devel). It helps adding and removing users for the roaming users using Raspberry Pi clients.

## Client Configuration

1. Make sure client is on time `systemctl restart systemd-timesyncd`
2. `apt-get update; apt-get install -y libnss-ldap libpam-ldap libpam-mount  winbind smbclient cifs-utils ldap-utils`
3. Add this information to the assistant: 
- LDAP server Uniform Resource Identifier: `ldap://192.168.8.105:389`
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

uri ldap://192.168.8.105:389

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
nss_initgroups_ignoreusers avahi,avahi-autoipd,backup,bin,colord,daemon,games,gnats,hplip,irc,kernoops,libuuid,lightdm,list,lp,mail,man,messagebus,news,proxy,pulse,root,rtkit,saned,speech-dispatcher,sshd,sync,sys,syslog,usbmux,uucp,whoopsie,www-data
```
5. To test configuration:
- `ldapsearch -D "uid=test,CN=Users,DC=pio,DC=local" -LLL -W uid=test`
- `ldapsearch -x -h 192.168.8.105 -p 389 -D "cn=Administrator,cn=Users,dc=pio,dc=local" -b "cn=Users,dc=pio,dc=local" -W`
6. Switch system auth to allow ldap on the authentication chain:
`auth-client-config -t nss -p lac_ldap`
7. Typing `id test` (being test a Samba/LDAP user) should show valid ID
8. Configure system for automount home folders in file `/etc/security/pam_mount.conf.xml`
```
<volume user="*" fstype="cifs" server="192.168.8.105" path="%(USER)" mountpoint="/home/%(USER)" options="workgroup=WORKGROUP,uid=%(USER),dir_mode=0700,file_mode=0700,nosuid,nodev" />
```
9. Also we need to make sure home dirs are created on server if they don't exist (first timers) at `/etc/pam.d/common-session`:
```
session required        pam_unix.so
session optional        pam_mount.so
session optional        pam_ldap.so
session optional        pam_systemd.so
session required        pam_mkhomedir.so skel=/etc/skel/ umask=0077
```

## Users Management

- Create user:
`sudo samba-tool user create USERNAME PASSWORD --unix-home /home/USERNAME --uid USERNAME`

- Delete user:
`sudo samba-tool user delete USERNAME`

- Change user password: 
`sudo samba-tool user setpassword USERNAME`
