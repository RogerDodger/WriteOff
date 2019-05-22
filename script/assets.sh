#!/bin/sh
cd $(dirname $0)/..
zip -r pics.zip root/static/pic
zip -r avatars.zip root/static/avatar
