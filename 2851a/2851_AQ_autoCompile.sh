#!/bin/bash

export USER=$(whoami)
NEED_COMPILE=false
SCRIPT_PATH=/home/zhengfeng_cao/.autoScript/db_script/2851a
CODE_PATH=/home/zhengfeng_cao/2851a_prebuilts
SQA_PATH=/home/zhengfeng_cao/2851a_prebuilts/SQA_DailyBuild
TVQC_ADB_PATH_TMP=$CODE_PATH"/DB_IMAGE"
VERSION_PATH=$CODE_PATH"/versionFolder"
DB_IMAGE_TARGET=/disk5/ae5_db_242/2851a
rm -rf $VERSION_PATH
mkdir $VERSION_PATH

if [ ! -d $TVQC_ADB_PATH_TMP ] || [ ! -w $TVQC_ADB_PATH_TMP ]; then
    mkdir -p $TVQC_ADB_PATH_TMP
fi

date
rm -rf $CODE_PATH"/kernel/android/android-10/out"

echo "start update 2851a code"
cd $CODE_PATH
repo forall -c "pwd;git log -1 HEAD | head -3;echo """ > $VERSION_PATH"/AndroidProjectsVersion_beforeUpdate"
repo forall -c "git clean -fxd" > $VERSION_PATH"/AndroidGitCleanLog"
repo forall -c "pwd;git reset --hard" > $VERSION_PATH"/AndroidGitResetLog"
cd $CODE_PATH
date
echo "start repo sync"
repo sync --force-sync
date
echo "repo sync end"
repo forall -c "pwd;git log -1 HEAD | head -3;echo """ > $VERSION_PATH"/AndroidProjectsVersion_afterUpdate"
date
echo "update andorid done, start to update SQA"
cd $SQA_PATH"/TV001_Tellus/bootcode"
svn up > $VERSION_PATH"/SQABootupdateLog"
cd $SQA_PATH"/TV036_Openmarket"
svn up > $VERSION_PATH"/SQAAvFwUpdateLog"
cd $CODE_PATH
date
echo "2851a update done!"

#if [ $NEED_COMPILE != "true" ]; then
#    echo "No sourcecode update, abandon compile!!"
#    exit 1
#fi

echo "start compile 2851a"
$SCRIPT_PATH/2851_AQ_BUILD.sh
echo "2851a compile done"

BUILD_NUMBER=$(cat $SCRIPT_PATH/BUILD_NUMBER)
IMAGE_FOLDER=$TVQC_ADB_PATH_TMP"/"$BUILD_NUMBER
if [ ! -d $IMAGE_FOLDER ] || [ ! -w $IMAGE_FOLDER ]; then
    mkdir -p $IMAGE_FOLDER
fi
cp -rf $VERSION_PATH $IMAGE_FOLDER
tar -zcvf $IMAGE_FOLDER/2851_AQ_autoCompile_log.tar.gz $SCRIPT_PATH/2851_AQ_autoCompile_log.log
cp -rf $IMAGE_FOLDER $DB_IMAGE_TARGET