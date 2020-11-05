#!/bin/bash -xe

# Get Build Num.
CODE_PATH=/home/zhengfeng_cao/2851a_prebuilts
SCRIPT_PATH=/home/zhengfeng_cao/.autoScript/db_script/2851a
BUILD_NUMBER=$(cat $SCRIPT_PATH/BUILD_NUMBER)
BUILD_NUMBER=`expr $BUILD_NUMBER + 1`
echo $BUILD_NUMBER > $SCRIPT_PATH/BUILD_NUMBER
TVQC_ADB_PATH_TMP=$CODE_PATH"/DB_IMAGE"

# Set record Files
WORKSPACE=`pwd`
File_Version=$WORKSPACE"/Version.txt"

export USE_CCACHE=1

MYCPUS_MAX=$(grep '^processor' /proc/cpuinfo | wc -l)
MY_SPEED=`expr $MYCPUS_MAX / 2`

# Check Build Time to start user build.
BUILD_TIME=$(date "+%H")


# SET PARAMS.
Root=$WORKSPACE
ANDVER="android-10"
ROOTFS_NAME="OdinAesir"
BOOTCODE="RTD28XOB8_A1_2K"
CFG="OdinAesir_2851a.cfg"
VIDEO_ADDNAME=".opt"
AUDIO_ADDNAME=".realtek_MS12V2"


# Write Version.txt
cd $Root


function Compile_Bootcode()
{
    cd ${Root}/bootcode/bin/RTD288O
    make PRJ=${BOOTCODE}
    cp ${Root}/bootcode/bin/bootloader.tar ${Root}/kernel/system/fw/
    cd -
}

function Compile_FW()
{
    BUILD_TYPE=$1
    BUILD_TYPE2=$2
    
    # Compile For Python version (2 or 3) 
	#singularity_exec="singularity exec /SIG/Android9_1604.simg"
 
    # SET PARAMS For 2K/4K.
    case ${BUILD_TYPE2} in
    2k)
    	ROOTFS_NAME="OdinAesir"
	BOOTCODE="RTD28XOB8_A1_2K"
	CFG="OdinAesir_2851a_dv.cfg"
    CFG_image="OdinAesir_2851a.cfg"
	VIDEO_ADDNAME=".opt"
	AUDIO_ADDNAME=".realtek_MS12V2"
    ;;
    4k)
     	ROOTFS_NAME="OpenMarket"
	BOOTCODE="RTD28XOB8_A1"
	CFG="OpenMarket_2851a.cfg"
    CFG_image="OpenMarket_2851a.cfg"
	VIDEO_ADDNAME=".opt"
	AUDIO_ADDNAME=".BD886041"   
    ;;
    esac
 
    #=======================2.Compile Image=======================
    echo "@@@@@ start to compile Image at $(date)"
    cd $Root
    
    echo "copy bootcode"
    cp -f "SQA_DailyBuild/TV001_Tellus/bootcode/"$BOOTCODE"/bootloader.tar" $Root/kernel/system/fw/bootloader.tar
 
    echo "copy video/audio optee fw"
    # VCPU 1
    cp -f "SQA_DailyBuild/TV036_Openmarket/AV_FW/bluecore.video.zip"$VIDEO_ADDNAME"" $Root/kernel/system/fw/bluecore.video.zip
    cp -f "SQA_DailyBuild/TV036_Openmarket/AV_FW/System.map.video"$VIDEO_ADDNAME $Root/kernel/system/fw/System.map.video
 
    # ACPU 1
    cp -f "SQA_DailyBuild/TV036_Openmarket/AV_FW/bluecore.audio.zip"$AUDIO_ADDNAME"" $Root/kernel/system/fw/bluecore.audio.zip
    cp -f "SQA_DailyBuild/TV036_Openmarket/AV_FW/System.map.audio"$AUDIO_ADDNAME $Root/kernel/system/fw/System.map.audio
 
    # OPTEE v3.0
    cp -f $Root/kernel/android/android-10/vendor/realtek/common/rtd2851a/optee/optee_os/optee_img_v3/tee.* $Root/kernel/system/fw/
    
    cd ${Root}/kernel/system
    case ${BUILD_TYPE} in
    user)
        #USE_CCACHE=1 $singularity_exec ./build_android.sh -p ${CFG} -c y -v ${BUILD_TYPE} -j ${MYCPUS_MAX} -k ~/.android-certs
        USE_CCACHE=1 ./build_android.sh -p ${CFG} -c y -v ${BUILD_TYPE} -j ${MYCPUS_MAX} -k ~/.android-certs
    ;;
    userdebug)
        #USE_CCACHE=1 $singularity_exec ./build_android.sh -p ${CFG} -c n -v ${BUILD_TYPE} -j ${MYCPUS_MAX}
        USE_CCACHE=1 ./build_android.sh -p ${CFG} -c y -v ${BUILD_TYPE} -j ${MY_SPEED}
       
    ;;
    esac
    cd -
    
    #Pack install.img
    cd ${Root}/image_creator
    python2 create_rtk_image.py --profile=${CFG_image} --bootcode=y
    mv -f ${Root}/image_creator/install.img ${Root}/image_creator/install_${BUILD_TYPE}_${BUILD_TYPE2}.img
    
    #build without bootcode
    python2 create_rtk_image.py --profile=${CFG_image}
    mv -f ${Root}/image_creator/install.img ${Root}/image_creator/install_${BUILD_TYPE}_${BUILD_TYPE2}_nobootcode.img
    cd -
}
 
    
function Create_Folder()
{
    #=======================3.Copy To Server======================= 
	IMAGE_FOLDER=$TVQC_ADB_PATH_TMP"/"$BUILD_NUMBER
	rm -rf $IMAGE_FOLDER
    rm -rf $WORKSPACE/kernel/system/tmp/toolchain
    
    mkdir -p ${IMAGE_FOLDER}/img
    # Put pkg file
    mkdir -p ${IMAGE_FOLDER}/pkg_out

    if [ ! -d ${IMAGE_FOLDER} ] || [ ! -w ${IMAGE_FOLDER} ]; then
        echo "@@@@Can't copy file to TVQC_ADB!!!  "
        return 1;
    fi
    
    rm -rf $WORKSPACE/kernel/system/toolchain


    if [ -L "$WORKSPACE/kernel/system/bin/sign_tool" ]
    then
    unlink $WORKSPACE/kernel/system/bin/sign_tool
    fi
     
    if [ -L "$WORKSPACE/kernel/android/android-10/vendor/realtek/common/ATV/frameworks/native/libs/common" ]
    then
    unlink $WORKSPACE/kernel/android/android-10/vendor/realtek/common/ATV/frameworks/native/libs/common
    fi
    
    mkdir -p $WORKSPACE/kernel/system/toolchain/gcc5
    ln -s $WORKSPACE/kernel/toolchain $WORKSPACE/kernel/system/toolchain/gcc5/asdk-6.4.1-a55-EL-4.4-g2.26-a32nut-170810
    ln -s $WORKSPACE/kernel/tools/sign_tool $WORKSPACE/kernel/system/bin/
    # 20191212 workaround for manifest linkfile or copyfile, it should write .gitignore to fix
    ln -s $WORKSPACE/kernel/linux/linux-4.14/drivers/rtk_kdriver/common $WORKSPACE/kernel/android/android-10/vendor/realtek/common/ATV/frameworks/native/libs/common
    
    mkdir -p $WORKSPACE/kernel/system/fw/
}

function COPY_TO_SERVER()
{
    BUILD_TYPE=$1
    BUILD_TYPE2=$2
    
    # Copy To Server
    cp -f ${Root}/image_creator/install_${BUILD_TYPE}_${BUILD_TYPE2}.img ${IMAGE_FOLDER}/install_${BUILD_TYPE}_${BUILD_TYPE2}_${BOOTCODE}_${BUILD_NUMBER}.img
    cp -f ${Root}/image_creator/install_${BUILD_TYPE}_${BUILD_TYPE2}_nobootcode.img ${IMAGE_FOLDER}/install_${BUILD_TYPE}_${BUILD_TYPE2}_nobootcode_${BUILD_NUMBER}.img 
    
    # add fw and prebuilts
    cd ${Root}/kernel/system
    mkdir -p ${IMAGE_FOLDER}/fw/${BUILD_TYPE2}
    tar -zcf ${IMAGE_FOLDER}/fw/${BUILD_TYPE2}/fw.tar.gz fw 2>/dev/null
	
    mkdir -p ${IMAGE_FOLDER}/prebuilts/${BUILD_TYPE2}
    cp prebuilts_rtk.tar.gz ${IMAGE_FOLDER}/prebuilts/${BUILD_TYPE2}/ 2>/dev/null
    
    mkdir -p ${IMAGE_FOLDER}/img/${BUILD_TYPE2}
    
    if [ $BUILD_TYPE == "user" ]; then
        mkdir -p ${IMAGE_FOLDER}/img/${BUILD_TYPE2}/$BUILD_TYPE
        cd ${Root}/kernel/android/android-10/out/target/product/${ROOTFS_NAME}/system/
        IMG_NAME=$(find build.prop | xargs grep build.fingerprint | awk -F "=" '{print $2}' | sed -e 's/\//\~/g' -e 's/:/\~/g' -e 's/test/release/g')

        cd ${Root}/image_creator/package7/ 
        #cd ../
        zip -r ${IMAGE_FOLDER}/${IMG_NAME}.zip super.img oem.img userdata.img boot.img recovery.img
        
        cp -f ${Root}/kernel/android/android-10/out/target/product/${ROOTFS_NAME}/android-info.txt ${IMAGE_FOLDER}/img/${BUILD_TYPE2}/$BUILD_TYPE/
        cp $WORKSPACE/kernel/android/android-10/signed-target_files.zip ${IMAGE_FOLDER}/img/${BUILD_TYPE2}/$BUILD_TYPE/
        cd ${IMAGE_FOLDER}/img/${BUILD_TYPE2}/$BUILD_TYPE/
        unzip -j signed-target_files.zip IMAGES/*.img
        rm dtbo.img
        unzip -j signed-target_files.zip PREBUILT_IMAGES/*.img
        rm signed-target_files.zip
        #cp -f $WORKSPACE/kernel/android/android-10/IMAGES/*.img ${IMAGE_FOLDER}/img/${BUILD_TYPE2}/$BUILD_TYPE/
        #cp -f $WORKSPACE/kernel/android/android-10/PREBUILT_IMAGES/*.img ${IMAGE_FOLDER}/img/${BUILD_TYPE2}/$BUILD_TYPE/
        #cp -f dtbo.img vbmeta.img super.img oem.img userdata.img boot.img recovery.img ${IMAGE_FOLDER}/img/${BUILD_TYPE2}
        cp -f $WORKSPACE/kernel/linux/linux-4.14/vmlinux ${IMAGE_FOLDER}/img/${BUILD_TYPE2}/$BUILD_TYPE/
    else
        mkdir -p ${IMAGE_FOLDER}/img/${BUILD_TYPE2}/$BUILD_TYPE
    	cd ${Root}/kernel/android/android-10/out/target/product/${ROOTFS_NAME}
        cp -f android-info.txt boot.img boot-debug.img dtbo.img vbmeta.img system.img vendor.img product.img odm.img userdata.img recovery.img ${IMAGE_FOLDER}/img/${BUILD_TYPE2}/$BUILD_TYPE/
        cp -f $WORKSPACE/kernel/linux/linux-4.14/vmlinux ${IMAGE_FOLDER}/img/${BUILD_TYPE2}/$BUILD_TYPE/
    fi
    # Copy AV pkg to Server
    cp -f $Root"/SQA_DailyBuild/TV036_Openmarket/AV_FW/pkg_output/bluecore.audio"$AUDIO_ADDNAME".pkg" ${IMAGE_FOLDER}/pkg_out
    cp -f $Root"/SQA_DailyBuild/TV036_Openmarket/AV_FW/pkg_output/bluecore.video"$VIDEO_ADDNAME".pkg" ${IMAGE_FOLDER}/pkg_out

    # OPTEE v3.0 pkg to Server
    cp -f $Root/kernel/android/android-10/vendor/realtek/common/rtd2851a/optee/optee_os/optee_img_v3/pkg/tee.pkg ${IMAGE_FOLDER}/pkg_out

    # Copy bootloader to Server
    cp -f $Root"/SQA_DailyBuild/TV001_Tellus/bootcode/"$BOOTCODE"/bootloader.tar" ${IMAGE_FOLDER}/pkg_out/bootloader_${BUILD_TYPE2}.tar
    cd -
}

echo "==== start to Create_Folder ===="
Create_Folder
echo "==== start to build userdebug 4k ===="
Compile_FW userdebug 4k
echo "==== start to COPY_TO_SERVER userdebug 4k ===="
COPY_TO_SERVER userdebug 4k

#echo "==== start to build userdebug 2k ===="
#Compile_FW userdebug 2k
#COPY_TO_SERVER userdebug 2k
