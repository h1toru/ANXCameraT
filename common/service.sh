MODDIR=${0%/*}

# wait for boot finish completely
until [ $(getprop sys.boot_completed) == '1' ]; do sleep 2; done

if [ $(getenforce) == 'Enforcing' ]; then setenforce 0
	if [ $(cat /sys/fs/selinux/enforce) == '1' ]; then
		chmod 777 /sys/fs/selinux/enforce
		echo '0' > /sys/fs/selinux/enforce
		chmod 644 /sys/fs/selinux/enforce
	fi
fi