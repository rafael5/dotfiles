#!/usr/bin/env bash
# Author: Alexander Epstein https://github.com/alexanderepstein

currentVersion="1.23.0" #This version variable should not have a v but should contain all other characters ex Github release tag is v1.2.4 currentVersion is 1.2.4
LANG="${LANG:-en}"
locale=$(echo "$LANG" | cut -c1-2)
unset configuredClient
if [[ $(echo "$locale" | grep -Eo "[a-z A-Z]*" | wc -c) != 3 ]]; then locale="en"; fi

## This function determines which http get tool the system has installed and returns an error if there isnt one
getConfiguredClient()
{
  if command -v curl &>/dev/null; then
    configuredClient="curl"
  elif command -v wget &>/dev/null; then
    configuredClient="wget"
  elif command -v http &>/dev/null; then
    configuredClient="httpie"
  elif command -v fetch &>/dev/null; then
    configuredClient="fetch"
  else
    echo "Error: This tool requires either curl, wget, httpie or fetch to be installed\." >&2
    return 1
  fi
}

## Allows to call the users configured client without if statements everywhere
httpGet()
{
  case "$configuredClient" in
    curl)  curl -A curl -s "$@" ;;
    wget)  wget -qO- "$@" ;;
    httpie) http -b GET "$@" ;;
    fetch) fetch -q "$@" ;;
  esac
}

getIPWeather()
{
  country=$(httpGet ipinfo.io/country) > /dev/null ## grab the country
  if [[ $country == "US" ]]; then ## if were in the us id rather not use longitude and latitude so the output is nicer
    city=$(httpGet ipinfo.io/city) > /dev/null
    region=$(httpGet ipinfo.io/region) > /dev/null
    if [[ $(echo "$region" | wc -w) == 2 ]];then
      region=$(echo "$region" | grep -Eo "[A-Z]*" | tr -d "[:space:]")
    fi
    httpGet $locale.wttr.in/"$city","$region""$1"
  else ## otherwise we are going to use longitude and latitude
    location=$(httpGet ipinfo.io/loc) > /dev/null
    httpGet $locale.wttr.in/"$location""$1"
  fi
}

getLocationWeather()
{
  args=$(echo "$@" | tr " " + )
  httpGet $locale.wttr.in/"${args}"
}

checkInternet()
{
  httpGet github.com > /dev/null 2>&1 || { echo "Error: no active internet connection" >&2; return 1; } # query github with a get request
}

usage()
{
  cat <<EOF
Weather
Description: Provides a 3 day forecast on your current location or a specified location.
  With no flags Weather will default to your current location.
Usage: weather or weather [flag] or weather [country] or weather [city] [state]
  weather [i][M] get weather in imperial units, optional M means windspeed in m/s
  weather [m][M] get weather in metric units, optional M means windspeed in m/s
  weather [Moon] grabs the phase of the moon
  -h  Show the help
  -v  Get the tool version
Examples:
  weather
  weather Paris m
  weather Tokyo
  weather Moon
  weather mM
EOF
}

getConfiguredClient || exit 1

while getopts "uvh" opt; do
  case "$opt" in
    \?) echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
    h)  usage
        exit 0
        ;;
    v)  echo "Version $currentVersion"
        exit 0
        ;;
    u)  checkInternet || exit 1 # check if we have a valid internet connection if this isnt true the rest of the script will not work so stop here
        update || exit 1
        exit 0
        ;;
    :)  echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
  esac
done

if [[ $# == "0" ]]; then
  checkInternet || exit 1
  getIPWeather || exit 1
  exit 0
elif [[ $1 == "help" || $1 == ":help" ]]; then
  usage
  exit 0
elif [[ $1 == "update" ]]; then
  checkInternet || exit 1
  update || exit 1
  exit 0
fi

checkInternet || exit 1
if [[ $1 == "m" ]]; then
  getIPWeather "?m" || exit 1
elif [[ "${@: -1}" == "m" ]];then
  args=$( echo "${@:1:(($# - 1))}" ?m | sed s/" "//g)
  getLocationWeather "$args" || exit 1
elif [[ $1 == "M" ]]; then
  getIPWeather "?M" || exit 1
elif [[ "${@: -1}" == "M" ]];then
  args=$( echo "${@:1:(($# - 1))}" ?M | sed s/" "//g)
  getLocationWeather "$args" || exit 1
elif [[ $1 == "mM" || $1 == "Mm" ]]; then
  getIPWeather "?m?M" || exit 1
elif [[ "${@: -1}" == "mM" || "${@:-1}" == "Mm" ]];then
  args=$( echo "${@:1:(($# - 1))}" ?m?M | sed s/" "//g)
  getLocationWeather "$args" || exit 1
elif [[ $1 == "iM" || $1 == "Mi" ]]; then
  getIPWeather "?u?M" || exit 1
elif [[ "${@: -1}" == "iM" || "${@:-1}" == "Mi" ]];then
  args=$( echo "${@:1:(($# - 1))}" ?u?M | sed s/" "//g)
  getLocationWeather "$args" || exit 1
elif [[ $1 == "i" ]]; then
  getIPWeather "?u" || exit 1
elif [[ "${@: -1}" == "i" ]];then
  args=$( echo "${@:1:(($# - 1))}" ?u | sed s/" "//g)
  getLocationWeather "$args" || exit 1
else
  getLocationWeather "$@" || exit 1
fi