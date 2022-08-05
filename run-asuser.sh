#!/bin/bash

if [ $# -eq 0 ]
  then
    echo "No username supplied"
else
  docker run -it -p 2222:22 csssh sudo -i -u $1 /bin/bash
fi
