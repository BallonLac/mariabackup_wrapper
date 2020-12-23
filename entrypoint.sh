#!/bin/sh

if [ $# -ge 1 ]; then
  if [ -f $1 ]; then
    if [ ! "$1" = "/home/mysql/.jobber" ]; then
      echo "jobber configuration file"
      cat $1 > /home/mysql/.jobber;
    else
      echo "jobber configuration is already the correct one"
    fi
  fi
fi

shift

/usr/lib/x86_64-linux-gnu/jobberrunner /home/mysql/.jobber $@
