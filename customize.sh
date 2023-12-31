##################################################
# TMMT CONFIGURATION SCRIPT
##################################################

anx_script() {
	# bootmode-only, abort recovery installation
	${BOOTMODE} || abort "! Installation via recovery is not supported!"

	# env. variables
	local CODENAME=$(getprop ro.product.device)
	local FEATDIR=${MODPATH}/system/etc/device_features
	local CODEDIR=${MODPATH}/system/etc/ANXCamera/cheatcodes
	local ANXDIR=/sdcard/.ANXCamera

	# check if device supported
	[ -d ${TMPDIR}/features ] || unzip -qo "${ZIPFILE}" 'features'/* -d "${TMPDIR}" >&2
	[ -f ${TMPDIR}/features/${CODENAME}.xml ] || abort "! Your device is not supported!"

	# apply features and config
	mkdir -p "${FEATDIR}"                                     "${CODEDIR}"
	cp -af   "${TMPDIR}/features/${CODENAME}.xml"             "${FEATDIR}/${CODENAME}.xml"
	cp -af   "${TMPDIR}/features/cheatcodes/${CODENAME}.json" "${CODEDIR}/cheatcodes.json" >&2 ||
	cp -af   "${TMPDIR}/features/cheatcodes/cheatcodes.json"  "${CODEDIR}/cheatcodes.json"

	# make user configuration files
	[ -d ${ANXDIR} ] && rm -rf ${ANXDIR}
	mkdir -p "${ANXDIR}/{cheatcodes,cheatcodes_reference,features,features_reference}"
	cp -af  "${FEATDIR}/${CODENAME}.xml" "${ANXDIR}/features/${CODENAME}.xml"
	cp -af  "${FEATDIR}/${CODENAME}.xml" "${ANXDIR}/features_reference/${CODENAME}.xml"
	cp -af  "${CODEDIR}/cheatcodes.json" "${ANXDIR}/cheatcodes/cheatcodes.json"
	cp -af  "${CODEDIR}/cheatcodes.json" "${ANXDIR}/cheatcodes_reference/cheatcodes.json"

	# remove other anxcamera module(s) to prevent conflict
	ls -A "${NVBASE}/modules" | grep -i 'ANX' |
	while read TARGET; do
		touch "${NVBASE}/modules/${TARGET%/}/remove"
	done

	# disable other camera package (com.android.camera) along with system-level permissions file(s) to prevent conflict
	CameraPackage=$(pm list packages -s -f "com.android.camera" | grep 'com\.android\.camera$' | sed 's|package:||g; s|\=.*||g; s|\(.*\)\/.*|\1|' | grep -v 'ANXCamera')
	[ -z ${CameraPackage} ] || echo "${CameraPackage}" > /data/backup/CameraPackage.txt
	# # using `REPLACE` variable because KernelSU does not support `.replace` method
	REPLACE="
	${CameraPackage:-$(cat /data/backup/CameraPackage.txt)}
	$(find /system/ -iname '*anxcamera*.xml' -o -iname '*miuicamera*.xml' 2>/dev/null)
	"

	# auto grant the app's user-level permissions
	local pkg=com.android.camera; local op=grant; local set=allow
	echo "pm clear ${pkg}"                             >> ${MODPATH}/service.sh
	echo "sleep 15"                                    >> ${MODPATH}/service.sh
	echo "dumpsys package ${pkg} | grep 'android\.permission' | egrep -v '\/' | sed 's|\:.*||g; s/\ //g; /^$/d' | sort -bi -u | uniq | while read perm; do pm ${op} ${pkg} \${perm} 2>/dev/null; done" >> ${MODPATH}/service.sh
	echo "appops get ${pkg} | sed 's|Uid\ mode\:||ig; s|\:.*||g; s/\ //g; /^$/d' | sort -bi -u | uniq | while read perm; do appops set --uid ${pkg} \${perm} ${set}; appops set ${pkg} \${perm} ${set}; done" >> ${MODPATH}/service.sh
	echo "sleep 15"                                    >> ${MODPATH}/service.sh
	echo "rm -f ${NVBASE}/modules/${MODID}/service.sh" >> ${MODPATH}/service.sh

	# enable EIS camera feature
	echo "persist.camera.eis.enabled=1" >> ${MODPATH}/system.prop

	# disable camera sounds
	echo "ro.camera.sound.forced=0" >> ${MODPATH}/system.prop
	find /system/media/audio/ui /system/product/media/audio/ui -type 'f' -iname 'camera*.ogg' -o -iname 'video*.ogg' 2>/dev/null | while read TARGET; do mktouch "${MODPATH}${TARGET}"; done

	# additional properties
	echo "vendor.camera.aux.packagelist=com.android.camera,app.grapheneos.camera"      >> ${MODPATH}/system.prop
	echo "vendor.camera.aux.packageblacklist=org.telegram.messenger,com.discord"       >> ${MODPATH}/system.prop
	echo "persist.vendor.camera.privapp.list=com.android.camera,app.grapheneos.camera" >> ${MODPATH}/system.prop

	# self-cleanup
	rm -rf ${MODPATH}/META-INF \
	       ${MODPATH}/.git* \
	       ${MODPATH}/*.md \
	       ${MODPATH}/features 2>/dev/null
}
anx_script

##################################################
# CUSTOM PERMISSIONS
##################################################

set_permissions() {
	# Usage for directory:
	#   set_perm_recursive  <dirname>          <owner> <group> <dirpermission> <filepermission> <contexts> (default: u:object_r:system_file:s0)
	# - Examples:
	#   set_perm_recursive $MODPATH/system/lib 0 0 0755 0644
	#   set_perm_recursive $MODPATH/system/vendor/lib/soundfx 0 0 0755 0644

	# Usage for single file:
	#   set_perm  <filename>                   <owner> <group> <permission> <contexts> (default: u:object_r:system_file:s0)
	# - Examples:
	#   set_perm $MODPATH/system/lib/libart.so 0 0 0644
	#   set_perm /data/local/tmp/file.txt 0 0 644

	# DO NOT MODIFY ANYTHING AFTER THIS
	ls -A ${MODPATH}/ | grep '\.sh' | while read sh_file; do chmod a+x ${sh_file}; done
}
