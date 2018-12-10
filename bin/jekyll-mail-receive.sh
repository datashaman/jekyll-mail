#!/usr/bin/env bash

umask 0002

/usr/local/bin/bundle exec bin/jekyll-mail $1 $2

cd $1 && jekyll build
