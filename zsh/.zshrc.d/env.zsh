#!/bin/zsh

variables=$(dotini env --list | grep '^variables\.' | sed 's/^variables\.//g')
for var in $variables; do
   export $var
done
