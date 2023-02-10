# append /home/cspasswd to /etc/passwd and /home/csgroup to /etc/group
PASSWD=/opt/passwd/cspasswd
GROUP=/opt/passwd/csgroup

if test -f "$PASSWD"; then
	echo "Populating /etc/passwd with CS entries"
	cat $PASSWD >> /etc/passwd
fi

if test -f "$GROUP"; then
	echo "Populating /etc/group with CS entries"
	cat $GROUP >> /etc/group
fi
