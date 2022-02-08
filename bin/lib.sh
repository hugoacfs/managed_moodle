#!/bin/bash

# Internal use only: Fetch configuration helper
config_read_file() 
{
   (grep -E "^${2}=" -m 1 "${1}" 2>/dev/null || echo "VAR=__UNDEFINED__") | head -n 1 | cut -d '=' -f 2-;
}
# Gets a variable from the config.cfg or config.cfg.defaults 
#  in case var does not exist
function config_get()
{
   val="$(config_read_file version.cfg "${1}")";
   printf -- "%s" "${val}";
}
# Get's Core Moodle by version and release (optional)
#  using the -v and -r tags - function taken from hugoacfs/upgroodle.
function get_moodle()
{
    VERSION=$VERSION
    RELEASE=$RELEASE
    MOODLE_VERSIONS=$SCRIPTPATH/moodle_versions
    if [ ! -d "$MOODLE_VERSIONS" ]
    then
        echo "Cannot find $MOODLE_VERSIONS directory, do you wish to create it now?"
        read -p "(Enter 'y' for yes, 'n' for no) : " confirmcreatedir
        if [[ $confirmcreatedir != 'y' ]]
        then
            echo "Aborting "
            exit 1
        fi
        echo "Creating dir $MOODLE_VERSIONS ..."
        mkdir $MOODLE_VERSIONS
    fi
    echo "Moodle version -> $VERSION"
    echo "Moodle release -> $RELEASE"
    STABLE="stable$VERSION"
    FILE="moodle-latest-$VERSION.tgz"
    FOLDERNAME="moodle-$VERSION"
    if [ "$RELEASE" != "" ]
    then
        FOLDERNAME="moodle-$VERSION-$RELEASE"
        FILE="moodle-$RELEASE.tgz"
        if [ -d "$MOODLE_VERSIONS/$FOLDERNAME" ]; then
            echo 'Release already available in moodle versions folder, skipping download...'
            PREVENTDOWNLOAD="1"
        fi
    else
        if [ -f "$MOODLE_VERSIONS/$FILE" ]
        then
            echo "Files already found, removing previous download from MOODLE_VERSIONS..."
            rm "$MOODLE_VERSIONS/$FILE"
            rm -R "$MOODLE_VERSIONS/$FOLDERNAME"
        fi
    fi
    echo "Downloading moodle from download.moodle.org..."
    if [ -z ${PREVENTDOWNLOAD+x} ] && wget "https://download.moodle.org/download.php/direct/$STABLE/$FILE"
    then
        if [ -d "$FOLDERNAME" ]; then
            echo "Folder with same name found, removing..."
            rm -r "$MOODLE_VERSIONS/$FOLDERNAME"
        fi
        echo "Uncompressing files..."
        if tar -xzf $FILE
        then
            echo "Moving files to MOODLE_VERSIONS..."
            mv $FILE "$MOODLE_VERSIONS/$FILE"
            mv "moodle" "$MOODLE_VERSIONS/$FOLDERNAME"
            echo "Fixing permissions of unzipped folder..."
            find "$MOODLE_VERSIONS/$FOLDERNAME/." -type f -exec chmod 0644 {} \;
            find "$MOODLE_VERSIONS/$FOLDERNAME/." -type d -exec chmod 0755 {} \;
            echo "Creating 'latest' directory from '$FOLDERNAME'"
            if [ -d "$MOODLE_VERSIONS/latest" ]
            then
                echo "Removing current LATEST folder and contents..."
                rm -r "$MOODLE_VERSIONS/latest"
            fi
            echo "Copying folder to LATEST folder..."
            cp -r "$MOODLE_VERSIONS/$FOLDERNAME" "$MOODLE_VERSIONS/latest"
        else
            echo "Removing temporary files..."
            rm $FILE
            rm -R "moodle"
        fi
    fi
    echo "get_moodle: Done."
}