#!/bin/sh

execCommand=$1
className=$2

running=$(hyprctl -j clients | jq -r ".[] | select(.class == \"${className}\") | .workspace.id")
echo $running

if [[ $running != "" ]]
then
	echo "focus"
	hyprctl dispatch focuswindow "class:${className}"
else 
	echo "start"
	${execCommand} & 
fi
