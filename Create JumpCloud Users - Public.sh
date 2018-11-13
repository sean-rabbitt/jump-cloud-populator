#!/bin/bash

## JumpCloud user populator script  
## v1.1 — — SRABBITT November 12, 2018 3:43 PM
##
## Description	Imports a CSV file of users and attributes to a JumpCloud server
##				via the API as there's no way to add attributes like Department,
##				Phone, Title, etc. through the web interface yet.
##				
##				If you have no list of users yet, will create a list of Simpsons 
##				characters to add to your JumpCloud server
##				
## Requirements Active JumpCloud account, access to the API key, and if you're
##				using only the evaluation version of JumpCloud, less than 1 user 
##				have an account (10 max before you need to pay).  Usually these
##				users are the evaluator and an ldapservice account
##
## Change Log	v1.0 - Initial release
##		v1.1 - Adds the user to the LDAP group automagically
##
## Usage		Change the API key, generic password (must contain 1 cap letter)
##				and if desired, point to a CSV of existing users.  If you don't have
##				an existing list, we'll add generic Simpsons characters.

PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

# Get an API key from JumpCloud API Settings under User in upper right corner of admin page
# Replace the API key here in the script or pass as the first argument.
apiKey=$1
# Users will be created with a set password; you can set that here or pass as the
# second argument
genericPassword=$2

# Path to the CSV containing the users to be added
pathToCSV=~/jumpclouduserlist.csv
IFS=,

# If you don't have a list of users yet, just uncomment out this section.
# Creates a list of default Simpsons users
# NOTE - You may need to modify the email address.  Because JumpCloud is one GIANT OU, someone
# might already have that email registered.  Do a find and replace for "bar.com" and replace with
# [someuniqueidentifyer].bar.com

# CSV Order is
# username email_address firstName lastName departmentName titleName building room phoneNumber


# Checks to see if the file exists first to not overwrite things.

if [ ! -f $pathToCSV ]; then
	cat << EOF > $pathToCSV
	frink,glaven@engineering.springfield.bar.com,John I.Q. Nerdelbaum,Frink Jr.,Engineering,Professor,Cupertino,A113,612-605-6625
	kbrockman,kbrockman@channel6.bar.com,Kent,Brockman,Marketing,Anchor,Minneapolis,News,612-605-6625
	ggunderson,gil@sales.bar.com,Gil,Gunderson,Sales,Salesman I,Cupertino,Cube 142,612-605-6625
	krusty,krusty@krustyburger.bar.com,Herschel Shmoikel Pinchas Yerucham,Krustofsky,Executive,CEO,Krusty Burger Headquarters,Exex1,612-605-6625
	ekrabappel,ekrabappel@k12.springfield.bar.com,Edna,Krabappel,EDU - Elementary,Teacher,Elementary School,4th Grade,702-799-2273
	skinner,steamedhams@k12.springfield.bar.com,Seymore,Skinner,EDU - Elementary,Principal,Elementary School,AdminOffice,702-799-2273
	hsimpson,plowking@nuke.bar.com,Homer,Simpson,Engineering,Nuclear Safety Inspector,Springfield Nuclear,Sector 7-G,301-415-7000
	cburns,sendinthehounds@nuke.bar.com,Charles Montgomery,Burns,Executive,CEO,Springfield Nuclear,Exec1,612-605-6625
	drhibbert,drhibbert@springfield.med.bar.com,Dr. Julius M,Hibbert,Executive,Doctor,Springfield General Hospital,Three Stooges Ward,612-605-6625
EOF
	removeFile=true
else
	removeFile=false
fi

# If the JumpCloud LDAP user has not been created yet, make one.
#/usr/bin/curl --request POST \
#	--url https://console.jumpcloud.com/api/systemusers/ \
#	--header 'Accept: application/json' \
#	--header 'Cache-Control: no-cache' \
#	--header 'Content-Type: application/json' \
#	--header 'x-api-key: '$apiKey  \
#	--data ''\''{\n "email": "ldapservice@bar.com",\n "username": "ldapservice",\n "allow_public_key": true,\n  "activated": true,\n "firstname": "ldap",\n "lastname": "service",\n "ldap_binding_user": true,\n "password_never_expires": true\n}'\'''

# Get the unique identifier for the LDAP ID Key
ldapServerID=$(curl -s --request GET \
	--url https://console.jumpcloud.com/api/v2/ldapservers/ \
	--header 'Accept: application/json' \
	--header 'Cache-Control: no-cache' \
	--header 'Content-Type: application/json' \
	--header 'x-api-key: '$apiKey \
	| python -mjson.tool | awk '/id/{print $2;exit;}' | tr -d '",')

# JumpCloud gives you ten users for free.  Let's create some users.  

# We created a CSV file - now we're going to read from it.
while 
	read username email_address firstName lastName departmentName titleName building room phoneNumber ; do
	
	# Okay this is ugly as sin, but what we're doing here is:
	# A - POST a new user to the LDAP server
	# B - Get from the json response the unique identifier for the user that was created
	# (That's the whole python - awk - tr end of the statement.)
	# Then, we're going to store that unique ID to a variable so we can do a put to link
	# that user to the LDAP service.
	
	ldapID=$(/usr/bin/curl -s --request POST \
		--url https://console.jumpcloud.com/api/systemusers/ \
		--header 'Accept: application/json' \
		--header 'Cache-Control: no-cache' \
		--header 'Content-Type: application/json' \
		--header 'x-api-key: '$apiKey \
		--data '{"username": "'$username'", "email": "'$email_address'", "firstname": "'$firstName'", "lastname": "'$lastName'", "department": "'$departmentName'", "jobTitle": "'$titleName'", "location": "'$building'", "activated": true, "ldap_binding_user": false, "password_never_expires": true, "password": "'$genericPassword'", "costCenter": "'$room'", "phoneNumbers": [{"type":"mobile", "number": "'$phoneNumber'"},{"type":"work", "number": "'$phoneNumber'"}] }' | python -mjson.tool | awk '/_id/{print $2;exit;}' | tr -d '",')
	
# Add that user to the LDAP Group
	curl --request POST \
			--url https://console.jumpcloud.com/api/v2/ldapservers/$ldapServerID/associations \
			--header 'Accept: application/json' \
			--header 'Cache-Control: no-cache' \
			--header 'Content-Type: application/json' \
			--header 'x-api-key: '$apiKey \
			--data '{ "op": "add", "type": "user", "id": "'$ldapID'"} '
	
done < $pathToCSV

# If we made the file, let's Girl Scout that camp site and clean it up.
if ( "$removeFile" = true ) ; then 
	rm $pathToCSV 
fi

echo "Complete.  Remember to create Groups and add users to those groups."