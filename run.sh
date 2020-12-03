#!/bin/sh

ERRORFILE=html/errors.html

# rotate the logs
#cd /opt/logmon/html
#
#rm index7.html 2>/dev/null
#mv index6.html index7.html 2>/dev/null
#mv index5.html index6.html 2>/dev/null
#mv index4.html index5.html 2>/dev/null
#mv index3.html index4.html 2>/dev/null
#mv index2.html index3.html 2>/dev/null
#mv index1.html index2.html 2>/dev/null

/usr/sbin/logrotate -f -s /opt/logmon/logrotate.state /opt/logmon/logrotate.conf

cd /opt/logmon
# create a web page
echo "<pre>" > $ERRORFILE
/opt/logmon/logmon.pl -w 1>html/index_1.html 2>>$ERRORFILE
echo "</pre>" >> $ERRORFILE

#echo "<h1>mysql slow</h1>" >>html/index1.html
#echo "<pre>" >>html/index1.html
#/usr/bin/mysqldumpslow -a -s c -t 10 2>&1 >>html/index1.html
#echo "</pre>" >>html/index1.html

# update if no logs found - header is 10 lines long
SIZE=$(wc -l html/index_1.html| awk '{print $1}')
if [ $SIZE -le 10 ] ; then
	echo "No logs found" >> html/index_1.html 
else
	# now email it
	cat html/index_1.html | mailx -a "Content-type: text/html" -s "logmon"  root
fi
