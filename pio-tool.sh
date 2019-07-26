#!/bin/bash

# Command usage menu
usage(){
  echo "
USAGE:
      `basename $0`
  Options:
      -a <username> -p <password> specify username and password to add user
      -d <username>        specify username to delete
      -c <username>        specify username to change password
      -l                   list all users in samba ldap
      -h                   this help
  "
  exit
}

if [ $# -lt 1 ]
then
  echo "Usage : $0 with arguments, use -h for help"
  exit
fi

while getopts ":hla:p:d:c:" OPTION; do
   case $OPTION in
     h )
        usage
        EXITCODE=1
        exit $EXITCODE
        ;;
     a )
        USERNAME=$OPTARG
        USECASE=add
        ;;
     p )
        PASSWORD=$OPTARG
        ;;
     d )
        USERNAME=$OPTARG
        USECASE=delete
       ;;
     c )
        USERNAME=$OPTARG
        USECASE=change
       ;;
     l )
        USECASE=list
       ;;
     : )
        echo ""
        echo "ERROR! - $OPTARG requires an argument"
        usage
        EXITCODE=1
        exit $EXITCODE
        ;;
     ? )
        echo ""
        echo "ERROR! Invalid option"
        usage
        EXITCODE=1
        exit $EXITCODE
        ;;
   esac
done

# main variables
ADD_USERS_SCRIPT=/tmp/add-samba-users.pl
ADD_USERS_CSV=/tmp/add-samba-users.csv 
GROUP=students
LOG_FILE=/tmp/pio-users.log
SAMBA_ADMIN_DN="CN=Administrator,CN=Users,DC=pio,DC=local"
SAMBA_ADMIN_PW="passwordhere"
LDIF_TEMP=/tmp/userchange.ldif

case $USECASE in
  add )
  # Create add users perl script on the fly
  cat <<'EOF' > $ADD_USERS_SCRIPT
#!/usr/bin/perl

use strict;
use warnings;

use EBox;
use EBox::Samba;
use EBox::Samba::User;
use EBox::Samba::Group;

EBox::init();

my $parent = EBox::Samba::User->defaultContainer();

open (my $USERS, '/tmp/add-samba-users.csv');

while (my $line = <$USERS>) {
  chomp ($line);
  if (substr($line, 0, 1) ne '#') {
    my ($group, $username, $firstname, $lastname, $password, $description) = split(',', $line);

    my %user;
    $user{parent}         = $parent;
    $user{group}          = $group;
    $user{samAccountName} = $username;
    $user{givenName}      = $firstname;
    $user{sn}             = $lastname;
    $user{password}       = $password;
    $user{description}    = $description; #optional

    my $nuser = EBox::Samba::User->create(%user);
    if ($nuser->exists()) {
      print "$username added\n";
      $nuser->addGroup(new EBox::Samba::Group(samAccountName => $user{group}));
      if ($nuser->exists()) {
        print "$username added to $group\n";
      }
    }
  }
}
close ($USERS);
1;
EOF

cat <<EOF > $ADD_USERS_CSV
$GROUP,$USERNAME,$USERNAME,$USERNAME,$PASSWORD,$USERNAME
EOF

# run the actual script
perl $ADD_USERS_SCRIPT $ADD_USERS_CSV

# run ldapmodify to adapt users to our configuration
cat <<EOF > $LDIF_TEMP
dn: CN=$USERNAME $USERNAME,CN=Users,DC=pio,DC=local
changetype: modify
replace: homeDirectory
homeDirectory: /home/$USERNAME
-
add: uid
uid: $USERNAME
-

EOF

      sleep 10
      ldapmodify -x -a -D $SAMBA_ADMIN_DN -w $SAMBA_ADMIN_PW -f $LDIF_TEMP

      cp -fr /home/tonitest/* /home/$USERNAME/
      chown -R $USERNAME:users /home/$USERNAME/*
      cp -fr /home/tonitest/.bashrc /home/$USERNAME/.bashrc
      cp -fr /home/tonitest/.profile /home/$USERNAME/.profile
      cp -fr /home/tonitest/.local /home/$USERNAME/
      cp -fr /home/tonitest/.config /home/$USERNAME/
      chown -R $USERNAME:users /home/$USERNAME/.bashrc
      chown -R $USERNAME:users /home/$USERNAME/.profile
      chown -R $USERNAME:users /home/$USERNAME/.local
      chown -R $USERNAME:users /home/$USERNAME/.config

     # logs it
     echo "`date` - Added user $USERNAME" >> $LOG_FILE
     ;;
  delete )
     samba-tool user delete $USERNAME
     echo "`date` - Deleted user $USERNAME" >> $LOG_FILE
     ;;
  change )
     samba-tool user setpassword $USERNAME
     echo "`date` - Changed password to user $USERNAME" >> $LOG_FILE
     ;;
  list )
     samba-tool user list
     echo "`date` - Listed users" >> $LOG_FILE
     ;;
esac
