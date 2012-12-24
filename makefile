#
# Makefile for honor2
#

# The original zip file, MUST be specified by each product
local-zip-file     := stockrom.zip

# The output zip file of MIUI rom, the default is porting_miui.zip if not specified
local-out-zip-file := MIUI_honor2.zip

# the location for local-ota to save target-file
local-previous-target-dir := ~/workspace/ota_base/honor2_4.1

# All apps from original ZIP, but has smali files chanded
local-modified-apps := SettingsProvider Gallery2

local-modified-jars :=

# All apks from MIUI
local-miui-removed-apps := MediaProvider Stk SettingsProvider

local-miui-modified-apps := MiuiHome Settings Phone Mms ThemeManager

include phoneapps.mk

# To include the local targets before and after zip the final ZIP file, 
# and the local-targets should:
# (1) be defined after including porting.mk if using any global variable(see porting.mk)
# (2) the name should be leaded with local- to prevent any conflict with global targets
local-pre-zip := local-pre-zip-misc
local-after-zip:= #local-put-to-phone

#include_thirdpart_app := true

# The local targets after the zip file is generated, could include 'zip2sd' to 
# deliver the zip file to phone, or to customize other actions

include $(PORT_BUILD)/porting.mk

# To define any local-target
local-pre-zip-misc:
	rm -f $(ZIP_DIR)/system/framework/hwframework.jar
	cp out/framework2.jar $(ZIP_DIR)/system/framework/framework_ext.jar
	rm -f $(ZIP_DIR)/system/framework/framework2.jar
	cp other/build_B530.prop $(ZIP_DIR)/system/build.prop
	cp other/bootanimation $(ZIP_DIR)/system/bin/
	cp other/StockSettings.apk $(ZIP_DIR)/system/app/
	cp other/Settings_ex.apk $(ZIP_DIR)/system/app/

#jar
%.phone : out/%.jar
	@echo push -- to --- phone
	adb push $< /system/framework
	adb shell su -c "chmod 644 /system/framework/$*.jar"
	adb shell stop
	adb shell start

out/framework2.jar : out/framework.jar
framework_ext.phone : framework2.phone
	adb push out/framework2.jar /system/framework/framework_ext.jar

#apk
%.sign-plat : out/%
	java -jar $(TOOL_DIR)/signapk.jar $(PORT_ROOT)/build/security/platform.x509.pem $(PORT_ROOT)/build/security/platform.pk8  $< $<.signed
	@echo push -- to --- phone
	adb push $<.signed /system/app/$*
	adb shell chmod 644 /system/app/$*

local-imgs-file := MIUI_honor2_imgs.zip
create-imgs: fullota
	create_image_zip/create_image_zip.sh out/target_files.zip out/$(local-imgs-file)

flash-imgs: create-imgs
	rm -rf out/imgs
	unzip -q -d out/imgs out/$(local-imgs-file) 
	adb reboot bootloader
	sleep 20
	fastboot flash userdata out/imgs/data.img
	sleep 1
	fastboot flash system out/imgs/system.img
	sleep 1
	fastboot reboot
	echo flash done!

local-rom-zip := MIUI_honor2.zip
local-put-to-phone:
	adb shell rm /sdcard/$(local-rom-zip)
	adb push out/$(local-rom-zip) /sdcard/
	adb reboot recovery

remount:
	adb shell su -c "mount -o rw,remount /dev/block/mmcblk0p15 /system"

#set-env: remount
#	adb shell su -c "cd /system/bin/; rm  find cp which rm;ln -s busybox cp; ln -s busybox rm; ln -s busybox  which; ln -s busybox find; ln -s busybox grep"

local-porting-sdcard:=/mnt/sdcard/porting
local-porting-tools:=$(local-porting-sdcard)/tools
root-phone: remount
	adb shell mkdir -p $(local-porting-tools)/
	adb push other/adbd $(local-porting-tools)/
	adb push other/insecure $(local-porting-tools)/
	adb shell su -c "cp $(local-porting-tools)/insecure /system/xbin/"
	adb shell su -c "chmod 777 /system/xbin/insecure"
	adb shell su -c "insecure"


fullota-to-phone: fullota
	adb push out/fullota.zip /sdcard/

apply-fullota: 
	if adb shell ls -l /sdcard/fullota.zip | grep -q "No such file or directory"; \
	then \
		echo "no fullota.zip in sdcard, update it"; \
		adb push out/fullota.zip /sdcard/; \
	else \
		md5_1=`md5sum out/fullota.zip | cut -d' ' -f1`; \
		md5_2=`adb shell md5sum /sdcard/fullota.zip | cut -d' ' -f1`; \
		if [ "$$md5_1" != "$$md5_2" ]; \
		then \
			echo "md5 is not same, update fullota.zip"; \
			adb push out/fullota.zip /sdcard/; \
		else \
			echo "md5 is same, skip update fullota.zip"; \
		fi \
	fi
	adb shell su -c 'cat /dev/null > /cache/recovery/command'
	adb shell su -c 'echo "--wipe_data" >> /cache/recovery/command'
	adb shell su -c 'echo "--wipe_cache" >> /cache/recovery/command'
	adb shell su -c 'echo "--update_package=/sdcard/fullota.zip" >> /cache/recovery/command'
	adb reboot recovery

