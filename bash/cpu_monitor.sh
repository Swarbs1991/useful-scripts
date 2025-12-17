CPU=$(sar 1 5 | grep "Average" | sed 's/^.* //')

if [ $CPU -lt 20 ]
then
   cat mail_content.html | /usr/lib/sendmail -t
else
   echo "Normal"
fi