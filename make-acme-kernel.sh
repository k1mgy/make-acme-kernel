#!/bin/bash
# ACME FOX G20 Linux 3.2.8 Kernel patcher and builder tool
# 1 MARCH 2012
# Mark Richards
# mark.richards@massmicro.com
#
# Uses patches provided by dougg and ACME Systems
# Uses .config created by me
#
# Fixed: 19 FEB 2012: Added LANG export for internationalization
#                     Fixed failure to copy ACME ADC module to the kernel/drivers/adc directory
# Update: 1 MAR 2012: Updated to use dougg's new patches for kernel 3.2.8
#                     Added option -a which, when selected, uses dougg's 320config in place of my own
#					  Fixed bug that caused script to fail when copying the ADC driver
#					  Added option -x which exits after patch process.  User must build manually thereafter.

export LANG=en_US.UTF-8 
START_TIME=`date +%s`
KERNEL="linux-3.2.8"
KERNEL_VER="3.2.8"
VERBOSE=0
ADC_DRIVER_DIR="/root/dev/at91-adc"
AT91_DRIVER_FILE="at91-adc.ko"
CONFIG_NAME=".config"

# pass exit code
function BYENOW
{
  if [ -z $1 ]
  then
    CODE=0;
  else
    CODE=$1
  fi

  END_TIME=`date +%s`
  DIFF=`echo "$END_TIME - $START_TIME" | bc`
  SECS=`echo $DIFF`
  PROGRESS "Done in $SECS seconds"
  exit $CODE
}


function PROGRESS 
{
  NOW=`date '+%H:%M:%S'`
  echo "$NOW $1"
}


function check_errs()
{
  # Function. Parameter 1 is the return code
  # Para. 2 is text to display on failure.
  if [ $1 -ne 0 ]; then
    PROGRESS "ERROR: ${2} (error code[$1])"
    # as a bonus, make our script exit with the right error code.
    BYENOW ${1}
  fi
}

FILES="gpio_dev32a.patch	i2c-at91_32dpg1.patch	fg20_spi304.patch	extra_i2c_313.patch	fg20_4_6_serial313.patch	mmc_core_sd_hc32.patch"

# the patch for ACME G20 V2
V2FILES="w1_slv_ds28ea00a.patch"


# check dirs
if  [ ! -d "/root/dev" ]
then
  mkdir /root/dev
  check_errs $? "Command[mkdir /root/dev] failed "
fi

if [ -f "$FLAGFILEDIR/PATCHED_OK" ]
then
  PATCHED_OK=`cat $FLAGFILEDIR/PATCHED_OK`
fi



function DoHelp 
{
  if [ $# -ne 0 ]
  then
    if [ $1 -eq 1 ]
    then
      echo "make-acme-kernel.sh: ERROR"	
    fi
  else
    echo "make-acme-kernel.sh"
  fi
  echo ""
  echo "This script, if everything works, create a complete kernel and root file system for the ACME Fox G20."
  echo "It will download the kernel sources, a modified makefile, a new .config, and download and apply the patches."
  echo "This script has been tested using the patches for kernel 3.2.2"
  echo "If you wish to make other modules, you will have to do so manually."
  echo ""
  echo "The default mode is to run the kernel patches in the --dry-run mode.  In this mode, no changes to the kernel are made."
  echo "When you are satisfied, run this script again, adding the -d switch, which will set the patch mode to execute."
  echo "If any of the patches fail, do not re-patch.  Fix the problem and begin again with a new kernel source tree."
  echo "A clean option is provided by this script to perform this task."
  echo ""
  echo "This script calls make menuconfig.  Be prepared to accept the configuration or change it at that time."
  echo ""
  echo "Uses patches provided by dougg and ACME Systems"
  echo ""
  echo "Parameter format"
  echo "  -g The GO command.  -g tells the script to execute"
  echo "  -2 Sets the script to apply patches for the ACME G20 Version 2 hardware"
  echo "  -d Turns off the patch dry-run flag (on by default)"
  echo "  -a Uses alternate .config (dy dougg)"
  echo "  -x Exit script after download and patch (allows you to make menuconfig;make;make modules;make modules_install manually)"
  echo "  -c Cleans the kernel source tree."
  echo "  -v Verbose mode"
  echo "  -h This help file"
  echo " "
  return 0
}




DRY_RUN=1
NOPARMS=1
V2HARDWARE=0
CLEAN_TREE=0
ALT_CONFIG=0
EXIT_AFTER_PATCH=0


which git > /dev/null 2>&1
check_errs $? "git required (to clone the ACME ADC code).  Do apt-get install git and try again"


while getopts "g2dhcvxa" Option
do
  case $Option in
    g ) 
      NOPARMS=0
      ;;
    2 )
      V2HARDWARE=1
      ;;
    x )
      EXIT_AFTER_PATCH=1
      ;;
    a )
      ALT_CONFIG=1
      ;;
    d )
      DRY_RUN=0
      PATCHED_OK=0
      echo 0 > $FLAGFILEDIR/PATCHED_OK
      ;;
    c )
      NOPARMS=0
      CLEAN_TREE=1
      ;;
    p )
      PATCHED_OK=0
      echo 0 > $FLAGFILEDIR/PATCHED_OK
      ;;
    v )
      VERBOSE=1
      ;;
    h )
      DoHelp 0
      exit 1
      ;;
    * )
      DoHelp 1
      exit 1
      ;;
  esac
done

if [ $DRY_RUN -eq 1 ]
then
  PATCHED_OK=0
fi

shift $(($OPTIND - 1))

if [ $NOPARMS -eq 1 ]
then 
  DoHelp
  BYENOW 0
fi


cd /root/dev
check_errs $? "Command[cd /root/dev] failed"

if [ -h /root/dev/linux ]
then
  rm -f /root/dev/linux
fi  

if [ $CLEAN_TREE -eq 1 ]
then
  PROGRESS "About to run [rm -fdr ./${KERNEL}]  OK? (y/n))"
  read OK
  if [ "${OK}" == "y" ]
  then
    rm -f $FLAGFILEDIR/PATCHED_OK
    rm -fdr ./${KERNEL}
    check_errs $? "Command[rm -fdr ./${KERNEL}] failed"
    PROGRESS "The kernel directory is clean."
  fi
  
  if [ -d "${ADC_DRIVER_DIR}" ]
  then
	rm -fdr ${ADC_DRIVER_DIR}
	check_errs $? "Command[rm -fdr ${ADC_DRIVER_DIR}] failed"
	PROGRESS "The old at91-adc files are also removed"
  fi
  BYENOW 0
fi  



if [ ! -f "${KERNEL}.tar.bz2" ]
then
  PROGRESS "Downloading kernel ${KERNEL}"
  if [ $VERBOSE -eq 1 ]
  then
    wget http://www.kernel.org/pub/linux/kernel/v3.x/${KERNEL}.tar.bz2  
  else
    wget -q http://www.kernel.org/pub/linux/kernel/v3.x/${KERNEL}.tar.bz2  
  fi
  check_errs $? "Command[wget http://www.kernel.org/pub/linux/kernel/v3.x/${KERNEL}.tar.bz2] failed"
fi

if [ ! -d "$KERNEL" ]
then
  PROGRESS "Extracting kernel (${KERNEL})..."
  if [ $VERBOSE -eq 1 ]
  then  
    tar -xjvf ${KERNEL}.tar.bz2 
  else
    tar -xjf ${KERNEL}.tar.bz2 > /dev/null 2>&1
  fi
  check_errs $? "Command[tar -xjf ${KERNEL}.tar.bz2] failed"
fi  

cd /root/dev
ln -sf ${KERNEL} linux


if [ ! -d "${ADC_DRIVER_DIR}" ]
then
	PROGRESS "Downloading ACME ADC code"
	if [ $VERBOSE -eq 1 ]
	then
		git clone git://github.com/AcmeSystems/at91-adc.git 
	else	
		git clone git://github.com/AcmeSystems/at91-adc.git > /dev/null 2>&1
	fi
	check_errs $? "Command[git clone git://github.com/AcmeSystems/at91-adc.git] failed"
	PROGRESS "Getting at91-adc-3.2.2.patch"
	if [ $VERBOSE -eq 1 ]
	then
		wget http://kumichan.net/g20/at91-adc-3.2.2.patch
	else 	
		wget -q http://kumichan.net/g20/at91-adc-3.2.2.patch
	fi	
	check_errs $? "Command[wget http://kumichan.net/g20/at91-adc-3.2.2.patch] failed"

	PROGRESS "Applying at91-adc-3.2.2.patch"
	cd ${ADC_DRIVER_DIR}
	check_errs $? "Command[cd ${ADC_DRIVER_DIR}] failed"

	if [ $VERBOSE -eq 1 ]
	then
		patch -p1 --dry-run <../at91-adc-3.2.2.patch
	else 	
		patch -p1 --dry-run <../at91-adc-3.2.2.patch > /dev/null 2>&1
	fi	
	check_errs $? "Patch command[patch -p1 --dry-run ../at91-adc-3.2.2.patch] failed.  As this is a dry run, no files were changed.  Correct the problem and try again"

	# now that dry-run worked, apply the patch
	if [ $VERBOSE -eq 1 ]
	then
		patch -p1 <../at91-adc-3.2.2.patch
	else 	
		patch -p1 <../at91-adc-3.2.2.patch > /dev/null 2>&1
	fi	
	check_errs $? "Patch command[patch -p1 ../at91-adc-3.2.2.patch] failed.  Cannot continue.  Fix the problem and start again."
	PROGRESS "The ADC code has been patched.  It will be built as a module later."
fi	

cd  /root/dev/${KERNEL}
check_errs $? "Command[cd /root/dev/${KERNEL}] failed "


PROGRESS "Downloading new ${CONFIG_NAME} (saving linux .config to .config.save)"

if [ -f ".config" ]
then  
  mv .config .config.save
fi  

rm -f /root/dev/${KERNEL}/.config

if [ ${ALT_CONFIG} -eq 1 ]
then
  CONFIG_NAME="320.config"
  rm -f ./${CONFIG_NAME}
  CONFIG_SRC="http://sg.danny.cz/foxg20/${CONFIG_NAME}"
else
  rm -f ./${CONFIG_NAME}
  CONFIG_SRC="http://kumichan.net/g20/${CONFIG_NAME}"
fi  

if [ $VERBOSE -eq 1 ]
then
  wget ${CONFIG_SRC}
else
  wget -q  ${CONFIG_SRC}
fi
check_errs $? "Command[wget ${CONFIG_SRC}] failed"

if [ $ALT_CONFIG -eq 1 ]
then
  cp ./${CONFIG_NAME} ./.config
fi  
MYDIR=`pwd`
echo "DIR=${MYDIR}"
if [ ! -f "/root/dev/${KERNEL}/.config" ]
then
  PROGRESS "ERROR: No /root/dev/${KERNEL}/.config after download"
  BYENOW 1
fi  


rm -f /root/dev/${KERNEL}/makefile

PROGRESS "Downloading new makefile from ACME"
if [ $VERBOSE -eq 1 ]
then
  wget http://foxg20.acmesystems.it/download/kernel_2.6.38/makefile
else
  wget -q http://foxg20.acmesystems.it/download/kernel_2.6.38/makefile
fi
check_errs $? "Command[wget http://foxg20.acmesystems.it/download/kernel_2.6.38/makefile] failed"

if [ ! -f "/root/dev/${KERNEL}/makefile" ]
then
  PROGRESS "ERROR: No /root/dev/${KERNEL}/makefile after download"
  BYENOW 1
fi


if [ $PATCHED_OK -eq 0 ]
then

  PROGRESS "Downloading patch files..."

  
  if [ $V2HARDWARE -eq 1 ]
  then
    files="${FILES}	${V2FILES}"
  else
    files="${FILES}"
  fi

  for cFile in $files 
  do
  
    if [ -f $cFile ]
    then
      PROGRESS "Already have patch file $cFile"
      continue
    fi
    PROGRESS "Downloading $cFile"
    rm -f /root/dev/${KERNEL}/${cFile}
    if [ $VERBOSE -eq 1 ]
    then
      wget http://sg.danny.cz/foxg20/${cFile}
    else
      wget -q  http://sg.danny.cz/foxg20/${cFile}
    fi
    check_errs $? "Command[wget http://sg.danny.cz/foxg20/${cFile}] failed"
    if [ ! -f "/root/dev/${KERNEL}/${cFile}" ]
    then
      PROGRESS "ERROR: Patch file /root/dev/${KERNEL}/${cFile} not found after downloading using command wget -q  http://sg.danny.cz/foxg20/${cFile} "
      BYENOW 1
    fi
    PROGRESS "  Downloaded OK"
  done  
  

  PROGRESS "Applying patches"
  for cFile in $files 
  do
  
    if [ ! -f $cFile ]
    then
      PROGRESS "ERROR: No patch file  $cFile"
      BYENOW 1
    fi
  
    if [ $DRY_RUN -eq 1 ]
    then
      PROGRESS "Patching $cFile using command[patch -p1 --dry-run < $cFile]"
      CMD="patch -p1 --dry-run < $cFile"
    else
      PROGRESS "Patching $cFile using command[patch -p1 < $cFile]"
      CMD="patch -p1 < $cFile"
    fi
    if [ $VERBOSE -eq 1 ]
    then
      sh -c "$CMD"
    else
      sh -c "$CMD" > /dev/null 2>&1
    fi
    check_errs $? "Command[$CMD] failed"
    PROGRESS " Patch[$cFile] OK"
  done  
  if [ $DRY_RUN -eq 1 ]
  then
    echo 1 > $FLAGFILEDIR/PATCHED_OK
  fi

fi

if [ $DRY_RUN -eq 1 ]
then
  PROGRESS "Dry run has completed.  If all patches are OK, run this script again with the -d -g switches."
  BYENOW 0
fi
if [ ${EXIT_AFTER_PATCH} -eq 1 ]
then
  PROGRESS "Exit After Patch selected.  Exiting now."
  PROGRESS "You should run these steps manually:"
  PROGRESS "  make menuconfig"
  PROGRESS "  make"
  PROGRESS "  make modules"
  PROGRESS "  make modules_install"
  PROGRESS "  "
  BYENOW 0
  exit 0
fi

make menuconfig
PROGRESS "Running make..."
if [ $VERBOSE -eq 1 ]
then  
  make
else
  make > /dev/null 2>&1
fi  
check_errs $? "Command[make] failed"

PROGRESS "Running make modules"
if [ $VERBOSE -eq 1 ]
then  
  make modules
else
  make modules > /dev/null 2>&1
fi  
check_errs $? "Command[make modules] failed"

PROGRESS "Running make modules_install"
if [ $VERBOSE -eq 1 ]
then  
  make modules_install
else
  make modules_install > /dev/null 2>&1
fi  
check_errs $? "Command[make modules_install] failed "

PROGRESS "Making the ADC code"
cd ${ADC_DRIVER_DIR}
check_errs $? "Command[cd ${ADC_DRIVER_DIR}] failed"

CMD="make KERNELDIR=/root/dev/${KERNEL}  ARCH=arm"
if [ $VERBOSE -eq 1 ]
then
	sh -c "$CMD"
else
	sh -c "$CMD" > /dev/null 2>&1
fi
check_errs $? "Command[$CMD] failed"
PROGRESS "ADC Module created"
	

PROGRESS "Creating gzip files of kernel uImage and the modules..."
if [ ! -d "/root/dev/${KERNEL}/foxg20-modules/lib/modules/${KERNEL_VER}/kernel/drivers/adc" ]
then
	mkdir "/root/dev/${KERNEL}/foxg20-modules/lib/modules/${KERNEL_VER}/kernel/drivers/adc"
	check_errs $? "Command[mkdir /root/dev/${KERNEL}/foxg20-modules/lib/modules/${KERNEL_VER}/kernel/drivers/adc] failed"
fi

cp -f  ${ADC_DRIVER_DIR}/${AT91_DRIVER_FILE} /root/dev/${KERNEL}/foxg20-modules/lib/modules/${KERNEL_VER}/kernel/drivers/adc/.
check_errs $? "Command[cp -f ${ADC_DRIVER_DIR}/${AT91_DRIVER_FILE}  /root/dev/${KERNEL}/foxg20-modules/lib/modules/${KERNEL_VER}/kernel/drivers/adc/.] failed"
	
if [ ! -f "/root/dev/${KERNEL}/foxg20-modules/lib/modules/${KERNEL_VER}/kernel/drivers/adc/${AT91_DRIVER_FILE}" ]
then
	check_errs 1 "Module file [/root/dev/${KERNEL}/foxg20-modules/lib/modules/${KERNEL_VER}/kernel/drivers/adc/${AT91_DRIVER_FILE}] not found."
fi	
PROGRESS "ADC kernel module built: /root/dev/${KERNEL}/foxg20-modules/lib/modules/${KERNEL_VER}/kernel/drivers/adc/${AT91_DRIVER_FILE}"

cd /root/dev/$KERNEL
check_errs $? "Command[cd /root/dev/$KERNEL] failed"


rm -f ../acme-kernel.tar.gz
rm -f ../acme-modules.tar.gz

if [ $VERBOSE -eq 1 ]
then
  tar -czvf ../acme-kernel.tar.gz uImage 
else
  tar -czf ../acme-kernel.tar.gz uImage >/dev/null 2>&1  
fi  
check_errs $? "Command[tar -czf ../acme-kernel.tar.gz uImage] failed "

cd /root/dev/$KERNEL/foxg20-modules
check_errs $? "Command[cd /root/dev/$KERNEL/foxg20-modules] failed"

if [ $VERBOSE -eq 1 ]
then
  tar -czvf ../../acme-modules.tar.gz ./
else
  tar -czf ../../acme-modules.tar.gz ./  >/dev/null 2>&1  
fi  
check_errs $? "Command[tar -czf ../acme-modules.tar.gz ./] failed"
cd ..
check_errs $? "Command[cd ..] failed"

PROGRESS "kernel image built OK.  "
PROGRESS "Extract acme-kernel.tar.gz for uImage"
PROGRESS "Extract acme-modules.tar.gz for modules"
PROGRESS "Bye"

BYENOW 0

exit 0
