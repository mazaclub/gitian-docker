#!/bin/bash


try () {
 sleep 420
 pgrep gbuild || break
}
main () {
while true ; do
   tail -n1 var/build.log
   sleep 5
   pgrep tail | xargs kill -1
   tail -f var/build.log &
   pgrep gbuild && tail -n1 var/build.log
   sleep 320
   echo "Testing to see if we're building"
   pgrep gbuild || try
done
}
main
echo "One Last check to see if we're building"
pgrep gbuild && main
exit
