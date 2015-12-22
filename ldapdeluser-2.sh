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
    echo "Delete all users in FILE from the LDAP server."
    echo
    echo "File must be in comma delimited (CSV) format in the following order:"
    echo
    echo "Password,LastName,FirstName,UserName"
    echo
    echo "Users will be deleted from the students OU by default. "
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

echo "deleting users:"
echo

# Read the fields from each line into variables and step through all the lines
while read PASSWORD LASTNAME FIRSTNAME USERNAME
do

    echo $PASSWORD $LASTNAME $FIRSTNAME $USERNAME

  #  USERNAME=`echo -en $USERNAME'\r'`
    # Convert the password into an MD5 hash of itself


# Delete LDAP entry
    cat << EOF|ldapdelete -v -x -D cn=admin,dc=hades,dc=lab -y ldap-admin-password.txt 
cn="$FIRSTNAME $LASTNAME",ou=people,dc=hades,dc=lab
EOF

#DELETE USERS FROM THE PLUGDEV GROUP; TO DISALLOW USB ACCESS

cat << EOF|ldapmodify -v -x -D cn=admin,dc=hades,dc=lab -y ldap-admin-password.txt 
dn: cn=plugdev,ou=groups,dc=hades,dc=lab
changetype: modify
delete: memberUid
memberUid: $USERNAME

dn: cn=dialout,ou=groups,dc=hades,dc=lab
changetype: modify
delete: memberUid
memberUid: $USERNAME

dn: cn=vboxusers,ou=groups,dc=hades,dc=lab
changetype: modify
delete: memberUid
memberUid: $USERNAME


EOF

#Delete a directory on the NFS share exported by cci-lab302-fs
ls /network-storage/"${USERNAME}"  

done < /tmp/ldap.tmp

rm /tmp/ldap.tmp

echo
echo "Done removing users."
echo
#echo "Buy me a beer."
echo
