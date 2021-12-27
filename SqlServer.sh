#!/bin/bash

function BinaryCheck {
  which $1 > /dev/null
  if [[ $? == 1 ]]; then
    echo "This script requires the $1 binary to be installed before execution. Please fix before proceeding."
    exit 255
  fi
}

function SedSafeString {
   echo $1 | sed "s/\//\\\\\//g"
}

BinaryCheck jq
if [[ $? != 0 ]]; then
  exit 255
fi

UNAME="$(uname -s)"
if [ "$UNAME" == "Linux" -a "$EUID" -ne 0 ]; then
  echo This script must be run as sudo on Linux platforms
  exit
fi

A1=$1
A2=$2
A3=$3

COMMAND=${A1:="x"}
SCRIPTNAME=${0##*/}
if [[ $COMMAND != "Init" && $COMMAND != "Create" && $COMMAND != "Destroy" ]]; then
   echo "Usage: $SCRIPTNAME Init                              Initializes a base docker image. This MUST be run before anything else!"
   echo "Usage: $SCRIPTNAME Create [[InstanceName] [Port]]    Creates a new instance (container) of Sql Server."
   echo "Usage: $SCRIPTNAME Destroy InstanceName              Destroys an existing instance (container) of Sql Server."
   exit
fi


COMPOSE=docker-compose
ACTION=${COMMAND:0:1}

DEFAULT_SUFFIX=mssqlserver
DEFAULT_INSTANCENAME=MSSQLSERVER
DEFAULT_PORT=1433
SQLSERVER2019_IMAGE=sqlserver_2019_full

if [[ $ACTION == D ]]; then
  DEFAULT_INSTANCENAME=
  DEFAULT_PORT=
fi
A2=$(echo $A2 | tr '[:lower:]' '[:upper:]')

INSTANCE_FOLDER=$PWD/Instances
export INSTANCENAME=${A2:=$DEFAULT_INSTANCENAME}
export PORT=${A3:="1433"}
export INSTANCEHOME=$INSTANCE_FOLDER/$INSTANCENAME
#export TIME_ZONE=$(readlink /etc/localtime | sed 's#/var/db/timezone/zoneinfo/##' | rev | cut -d/ -f -2|rev | sed 's/\/\\\/g')
export TIME_ZONE=$(readlink /etc/localtime | rev | cut -d/ -f -2|rev)

CONTAINERNAME=SqlServer2019_$INSTANCENAME
LOWERCASE_INSTANCENAME=$(echo $INSTANCENAME | tr '[:upper:]' '[:lower:]')
DEFAULT_CONTAINERNAME=${LOWERCASE_INSTANCENAME}_sqlserver2019_1
VOLUMENAME_MSSQL=${LOWERCASE_INSTANCENAME}_SqlServer2019-mssql
VOLUMENAME_DATA=${LOWERCASE_INSTANCENAME}_SqlServer2019-UserDataAndLogs

SOURCEFILES=$PWD/DockerFiles
if [[ "${SUDO_USER}" != "" ]]; then
  ME=${SUDO_USER}
else
  ME=$USER
fi
which docker-compose > /dev/null 2>&1
if [[ $? == 1 ]]; then
  export COMPOSE=docker\ compose
fi

# Kludge to allow the fold statement following to work...

for arg do
  shift
done

#export MSSQL_SA_PASSWORD=$(cat /dev/urandom | tr -dc '[:alnum:]' | fold -w ${1:-32} | head -n 1)
export MSSQL_SA_PASSWORD=$(openssl rand -base64 33)

if [[ $ACTION == "I" ]]; then

  docker images $SQLSERVER2019_IMAGE|grep "$SQLSERVER2019_IMAGE" > /dev/null 2>&1
  if [[ $? == 0 ]]; then
    echo "The image already exists."
    exit 1
  fi
  pushd "$SOURCEFILES"
  docker build --tag sqlserver_2019_full .
  popd > /dev/null
  exit
fi


if [[ $ACTION == D ]]; then
  if [[ "$INSTANCENAME" == "" ]]; then
    echo "The Instance Name to destroy was not supplied."
    exit 2
  fi
  if [[ ! -d $INSTANCEHOME ]]; then
     echo "Unable to locate the folder for $INSTANCENAME."
     exit 1
  fi

  docker container ls --all|grep "$CONTAINERNAME\$" > /dev/null
  if [[ $? == 1 ]]; then
    echo "Unable to locate a container for the Instance ($CONTAINERNAME)."
    exit 3
  fi

  IS_RUNNING=$( docker inspect $CONTAINERNAME|jq '.[0].State.Running')
  IS_PAUSED=$( docker inspect $CONTAINERNAME|jq '.[0].State.Paused')

  if [[ $IS_RUNNING == true || $IS_PAUSED == true ]]; then
     echo "Please stop the container before attempting to destroy it."
     exit 2
  fi

  echo "Type CONFIRM to confirm you wish to destroy this instance. This will then delete ALL the instance data."
  read CONFIRM

  if [[ "$CONFIRM" != "CONFIRM" ]]; then
    echo "Destruction aborted"
    exit 0
  fi

  docker stop $CONTAINERNAME > /dev/null 2>&1
  docker rm $CONTAINERNAME > /dev/null 2>&1
  docker volume rm $VOLUMENAME_MSSQL > /dev/null 2>&1
  docker volume rm $VOLUMENAME_DATA > /dev/null 2>&1
  rm -rf "$INSTANCEHOME"

  echo "Instance $INSTANCENAME (Container $CONTAINERNAME) has been destroyed."
  exit
fi

if [[ $ACTION == C ]]; then

   docker images $SQLSERVER2019_IMAGE|grep "$SQLSERVER2019_IMAGE" > /dev/null 2>&1
   if [[ $? == 1 ]]; then
     echo "Please run $SCRIPTNAME Init to create the base image before proceeding."
     exit 1
   fi
   if [[ -d $INSTANCEHOME ]]; then
      echo "The folder for instance $INSTANCENAME already exists."
      exit 1
   fi
   lsof -i4TCP@0.0.0.0:$PORT| grep LISTEN > /dev/null 2>&1
   #netstat -a|grep ":$PORT "|grep -i listen > /dev/null

   if [[ $? -eq 0 ]]; then
      echo "Port $PORT is already in use."
      exit 1
   fi

   if [[ ! -d $INSTANCE_FOLDER ]]; then
     mkdir "$INSTANCE_FOLDER"
     chown -R $ME "$INSTANCE_FOLDER"
     chmod -R 700 "$INSTANCE_FOLDER"
   fi

   mkdir "$INSTANCEHOME" > /dev/null 2>&1
   pushd "$INSTANCEHOME" > /dev/null

   mkdir Backups Files > /dev/null 2>&1
   SEDSAFE_INSTANCEHOME=$(SedSafeString "$INSTANCEHOME")
   SEDSAFE_TIME_ZONE=$(SedSafeString $TIME_ZONE)
   SEDSAFE_MSSQL_SA_PASSWORD=$(SedSafeString $MSSQL_SA_PASSWORD)

   sed  -e "s/%INSTANCEHOME/$SEDSAFE_INSTANCEHOME/g" -e "s/%MSSQL_SA_PASSWORD/$SEDSAFE_MSSQL_SA_PASSWORD/g" -e "s/%TIME_ZONE/$SEDSAFE_TIME_ZONE/g" -e "s/%PORT/$PORT/g" "$SOURCEFILES/docker-compose.yml.source" > docker-compose.yml
   jq -n --arg instanceName $INSTANCENAME --arg port $PORT --arg sa "$MSSQL_SA_PASSWORD"  '{instanceName: $instanceName, port: $port, sa, $sa}' > config.json
   chmod 700 "$INSTANCEHOME/config.json"
   $COMPOSE up -d
   MSSQL_VOLUME=$(docker volume inspect $VOLUMENAME_MSSQL |jq  '.[0].Mountpoint' | cut -d\" -f2)
   chown -R $ME "$INSTANCEHOME"
   chmod -R 700 "$INSTANCEHOME"
   docker rename $DEFAULT_CONTAINERNAME $CONTAINERNAME
   ln -sf $MSSQL_VOLUME/log Log 2> /dev/null
   echo "Sql Server is running: sa =  $MSSQL_SA_PASSWORD"
   popd > /dev/null
fi
