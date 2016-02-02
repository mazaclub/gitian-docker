#!/bin/bash


try () {
 tail -n5 var/build.log
 sleep 300
 tail -n5 var/build.log
 pgrep gbuild || exit 0
}
main () {
while true ; do
   tail -n5 var/install.log
   sleep 10
   pgrep gbuild && tail -n5 var/build.log
   sleep 30
   echo "Testing to see if we're building"
   pgrep gbuild || try
done
}
main
