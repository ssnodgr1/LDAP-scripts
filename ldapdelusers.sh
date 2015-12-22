#!/bin/bash

# Originally Written by Jonathan Blanton, 2010-01-13
# Updated, modernized and generally made badass by Noah Putman and Sean Snodgrass.
# This is not even the same script anymore. Maybe we should remove the credits to
# this guy. I'm just too lazy right now.

# If no file provided (or the file can't be read) give a usage summary and gripe.
# If you can't figure it out then read the usage summary again. If you still
# aren't getting it then I suggest a visit to your local library. Below is a list of
# recommended materials, by ISBN.

# 1118115538
# 0789742535
# 0764541471

if [ $# -ne 1 ] || [ ! -f $1 ]; then
    if [ ! -f $1 ]; then
        echo
        echo "File $1 does not exist or is not a regular file!"
    fi
    echo
    echo "Usage: $0 FILE"
    echo "Add all users in FILE to LDAP server."
    echo
    echo "File must be in comma delimited (CSV) format in the following order:"
    echo
    echo "Password,LastName,FirstName,UserName"
    echo
    echo "Users will be added to the students OU by default. The passwords from"
    echo "the file will be converted to an MD5 hash before stored in the LDAP"
    echo "database."
    echo
    exit 1
fi


# Find out if this is file uses CR, LF, or CRLF line termination
FILETYPE=`file -b $1`

# Convert to LF line termination, make a temp file to work from
if [ "$FILETYPE" == 'ASCII text, with CR line terminators' ]; then
    cat $1 | tr '\r' '\n' > /tmp/ldap.tmp
elif [ "$FILETYPE" == 'ASCII text, with CRLF line terminators' ]; then
    cat $1 | tr -d '\r' > /tmp/ldap.tmp
else
    cat $1 > /tmp/ldap.tmp
fi

# We're reading a CSV so we will specify comma to be our delimiter
IFS=,

echo "Adding users:"
echo

# Read the fields from each line into variables and step through all the lines
while read PASSWORD LASTNAME FIRSTNAME USERNAME
do

    echo $PASSWORD $LASTNAME $FIRSTNAME $USERNAME

    USERNAME=`echo -en $USERNAME'\r'`
    # Convert the password into an MD5 hash of itself
    PASSWORD=`echo -n $PASSWORD | openssl md5 -binary | base64`

    # Find the largest used LDAP UID
    UIDNUMBER="`ldapsearch -D cn=admin,dc=hades,dc=lab -y ldap-admin-password.txt -x -b 'dc=hades,dc=lab' uidNumber | grep uidNumber | cut -f 2 -d ' '|sort -n|tail -n 1`"

    # We actually want the next one for our new user, so increment
    UIDNUMBER=$((UIDNUMBER+1))

    # Add LDAP entry
cat << EOF|ldapadd -v -x -D cn=admin,dc=hades,dc=lab -y ldap-admin-password.txt &> /dev/null
dn: cn=$FIRSTNAME $LASTNAME,ou=people,dc=hades,dc=lab
uid: $USERNAME
uidNumber: $UIDNUMBER
gidNumber: 500 # create an unpriveledged user, 501 is the admin group
givenName: $FIRSTNAME
cn: $FIRSTNAME $LASTNAME
sn: $LASTNAME
objectClass: top
objectClass: inetOrgPerson
objectClass: posixAccount
loginShell: /bin/bash
homeDirectory: /home/$USERNAME
userPassword: {md5}$PASSWORD

#ADD USERS TO THE PLUGDEV GROUP; TO ALLOW USB ACCESS
dn: cn=plugdev,ou=groups,dc=hades,dc=lab
changetype: modify
add: memberUid
memberUid: $USERNAME

#ADD USERS TO THE DIALOUT GROUP; TO ALLOW SERIAL PORT ACCESS
dn: cn=dialout,ou=groups,dc=hades,dc=lab
changetype: modify
add: memberUid
memberUid: $USERNAME

#ADD USERS TO THE VBOXUSERS GROUP; TO ALLOW THE USAGE OF VIRTUALBOX
dn: cn=vboxusers,ou=groups,dc=hades,dc=lab
changetype: modify
add: memberUid
memberUid: $USERNAME


EOF

#Create a directory on the NFS share exported by cci-lab302-fs
mkdir /network-storage/$USERNAME  
chown -R $UIDNUMBER:500 #change the ownership of the newly created directory
chmod 700 /network-storage/$USERNAME #set the owndership on the newly created directory.
done < /tmp/ldap.tmp
rm /tmp/ldap.tmp

echo
echo "Done adding users."
echo
#echo "Buy me a beer."
echo
