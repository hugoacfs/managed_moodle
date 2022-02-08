#!/bin/bash

# Loading library functions.
source lib.sh; 

SUDO=(`command -v sudo`)
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
MIGRATIONPATH=$SCRIPTPATH/..
WWWPATH=$SCRIPTPATH/../www/
MOODLE_VERSIONS=$SCRIPTPATH/moodle_versions
PMPATH=$SCRIPTPATH/pluginmanager
VERSION="$(config_get VERSION)"
RELEASE="$(config_get RELEASE)"

# We have to setup a symlink if it hasn't been done yet.
echo "Looking for plugins.json before starting..."
if [ -f "$PMPATH/plugins.json" ];
then
   echo "plugins.json found!"
else
   echo "plugins.json not found, creating symlink..."
   echo ln -s $MIGRATIONPATH/plugins.json $PMPATH/plugins.json
   ln -s $MIGRATIONPATH/plugins.json $PMPATH/plugins.json
   echo "done!"
fi

# Release version is a required parameter.
while getopts "smd" opt
do
   case "$opt" in
      s ) SKIPPURGE="1" ;;
      m ) MAKEHASH="1" ;;
      d ) DEVMODE="1" ;;
      ? ) echo "Error: Unexpected option used." ;;
      # Runs when parameter is not in the list.
   esac
done

# If no version specified, this release should not run.
if [ -z "$VERSION" ]
then
   echo -e "Could not find Moodle version in version.cfg, aborting";
   exit 1
fi

if (( $VERSION <= 39 && $VERSION >= 34 )) ||
   (( $VERSION <= 311 && $VERSION >= 310 ))
then
   echo "Version requested: $VERSION ...";
else
   echo "Version requested not supported: $VERSION ... aborting.";
   exit 1
fi

echo '=========='
echo 'Release.sh'
echo '=========='

echo 'This script will: '
echo ' 1. Purge some plugins from pm and core from moodle_versions folder, '
echo '    to skip specify -s option.'
echo ' 2. Grab plugins from git repos using pluginmanager'
echo '     and grab core code from Moodle HQ.'
echo ' 3. Sync everything up in moodle_migration/www/html'
echo ' 4. Check hash matches the last saved hash OR '
echo '     produce a new hash release with -m option.'

echo ''
read  -n 1 -p "Press enter to contiue or CTRL + C to abort."
echo ''

# Step 1: Purge stuff before release.
if [[ $SKIPPURGE != "1" ]]
   then
      echo "1. Purging directories:"
      echo " - Plugin Manager plugins folder."
      echo " - HTML release folder in ../www."
      echo " - Moodle Versions folder.."

      cd $PMPATH
      php pm.php -p
      cd $WWWPATH
      $SUDO rm -r $MOODLE_VERSIONS/*

      read  -n 1 -p "Press enter to contiue or CTRL + C to abort."
fi

# Step 2: Prepare files for sync.

echo "2. Preparing files for sync:"
echo " - Fetching plugins using plugin manager."
echo " - Verifying plugin versions using plugin manager."
echo " - Fetching core (VERSION: $VERSION - RELEASE: $RELEASE)."

cd $PMPATH
# If skip purge mode is not set, will download again.
if [[ $SKIPPURGE != "1" ]]
   then
   php pm.php -c
   # And if dev mode is not set, will remove git stuff.
   if [[ $DEVMODE != "1" ]]
      then
      php pm.php -s
   fi
fi

php pm.php -v
get_moodle

echo ''
read  -n 1 -p "Press enter to contiue or CTRL + C to abort."
echo ''

# Step 3: Sync everything up.

echo "3. Syncing core, plugins and misc files to moodle_migration/www/html folder."

cd $SCRIPTPATH
mkdir $WWWPATH/html
$SUDO rsync -avz $WWWPATH/html-dist/ $WWWPATH/html/
$SUDO rsync -avz $MOODLE_VERSIONS/latest/ $WWWPATH/html/
$SUDO rsync -avz $PMPATH/plugins/ $WWWPATH/html/

# Changing ownership to www-data
$SUDO chown -R www-data:www-data $WWWPATH/html/

# Fixing all dirs and files.
$SUDO find $WWWPATH/html/. -type f -exec chmod 0644 {} \;
$SUDO find $WWWPATH/html/. -type d -exec chmod 0755 {} \;

# These are files that need to remain executable.
$SUDO find $WWWPATH/html/. -type f -name "mimetex.darwin" -exec chmod 0755 {} \;
$SUDO find $WWWPATH/html/. -type f -name "mimetex.exe" -exec chmod 0755 {} \;
$SUDO find $WWWPATH/html/. -type f -name "mimetex.linux" -exec chmod 0755 {} \;
$SUDO find $WWWPATH/html/. -type f -name "mimetex.freebsd" -exec chmod 0755 {} \;
$SUDO find $WWWPATH/html/. -type f -name "algebra2tex.pl" -exec chmod 0755 {} \;

# If devmode, don't check hash.
# Also prevents the make -m option, since we don't want to override the hash.
if [[ $DEVMODE == "1" ]]
   then
   echo "Devmode on, not checking/making hash."
   echo "Script exiting..."
   echo ''
   read  -n 1 -p "Press enter to end script."
   echo ''
   echo "Release script done."
   exit 0
fi

if [[ $MAKEHASH == "1" ]]
   then
   echo "Producing MD5 hash and saving to verify folder (might take a while):"
   php $SCRIPTPATH/checkhash.php producehash
   echo "Done."
fi
if [[ $MAKEHASH != "1" ]]
   then
   echo "Checking MD5 hash matches expected hash (might take a while):"
   php $SCRIPTPATH/checkhash.php
fi

echo ''
read  -n 1 -p "Press enter to end script."
echo ''

echo "Release script done."