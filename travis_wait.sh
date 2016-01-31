#!/bin/bash


try () {
 sleep 120
 pgrep gbuild || exit
}
while true ; do
   tail -n1 var/build.log
   sleep 120
   pgrep gbuild && tail -n1 var/build.log
   sleep 120
   pgrep gbuild || try
   sleep 120
done
