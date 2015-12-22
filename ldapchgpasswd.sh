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
    echo "Change the password for all of the users in FILE."
    echo
    echo "File must be in comma delimited (CSV) format in the following order:"
    echo
    echo "Password,LastName,FirstName,UserName"
    echo
    echo "Users whose passwords are changed will be in the students OU by default. The passwords from"
    echo "the file will be converted to an MD5 hash before bieng stored in the LDAP"
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


# Read the fields from each line into variables and step through all the lines
while read PASSWORD LASTNAME FIRSTNAME USERNAME
do

echo;echo "Changing password for $USERNAME."

echo;echo $PASSWORD $LASTNAME $FIRSTNAME $USERNAME
 
echo

    USERNAME=`echo -en $USERNAME'\r'`
    # Convert the password into an MD5 hash of itself
    PASSWORD="`echo -n $PASSWORD | openssl md5 -binary | base64`"

    # Add LDAP entry
cat << EOF|ldapmodify -v -x -D cn=admin,dc=hades,dc=lab -y ldap-admin-password.txt &> /dev/null
dn: cn="$FIRSTNAME $LASTNAME",ou=people,dc=hades,dc=lab
changetype: modify
replace:userPassword
userPassword:{md5}$PASSWORD
EOF

done < /tmp/ldap.tmp
rm /tmp/ldap.tmp

echo
echo "Done changing users passwords."
echo
#echo "Buy me a beer."
