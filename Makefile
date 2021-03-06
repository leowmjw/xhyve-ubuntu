SHELL := /bin/bash

HDD_SIZE=16
HDD_IMG?=hdd.img
IDENTIFIER?=com.erianna.lxe
PKG_NAME?=lxe.pkg
VERSION?=0.1

# Remove the local build staging area
clean:
	rm -rf *.img mini.iso initrd.gz linux ./boot/*

# Does the majority of the build process
build: download_netboot create_disk_image
	xhyve -m 2G -c 1 -s 2:0,virtio-net \
		-s 3,ahci-cd,mini.iso -s 4,virtio-blk,$(HDD_IMG) \
		-s 0:0,hostbridge -s 31,lpc -l com1,stdio \
		-f "kexec,linux,initrd.gz,earlyprintk=serial \
		console=ttyS0 acpi=off root=/dev/vda1 ro"

# Downloads the netboot images
download_netboot:
	wget http://archive.ubuntu.com/ubuntu/dists/xenial-updates/main/installer-amd64/current/images/netboot/ubuntu-installer/amd64/initrd.gz
	wget http://archive.ubuntu.com/ubuntu/dists/xenial-updates/main/installer-amd64/current/images/netboot/ubuntu-installer/amd64/linux
	wget http://archive.ubuntu.com/ubuntu/dists/xenial-updates/main/installer-amd64/current/images/netboot/mini.iso

# Creates a disk image with the requested size
create_disk_image:
	dd if=/dev/zero of=$(HDD_IMG) bs=1g count=0 seek=$(HDD_SIZE)

# Installs the /boot and $(HDD_IMG) files to persistent storage, then
install: pre-install launchctl

preinstall:
	mkdir -p /Library/Containers/$(IDENTIFIER)/boot
	cp -R ./boot/* /Library/Containers/$(IDENTIFIER)/boot/
	cp ./boot.sh /Library/Containers/$(IDENTIFIER)
	cp $(HDD_IMG) /Library/Containers/$(IDENTIFIER)

launchctl:
	if [ -f /Library/LaunchDaemons/xhyve.lxe.erianna.com.plist ]; then  \
		launchctl unload /Library/LaunchDaemons/xhyve.lxe.erianna.com.plist; \
	fi
	
	cp ./headless.sh /Library/Containers/$(IDENTIFIER)
	chmod a+x  /Library/Containers/$(IDENTIFIER)/headless.sh
	cp xhyve.lxe.erianna.com.plist /Library/LaunchDaemons/
	chown root /Library/LaunchDaemons/xhyve.lxe.erianna.com.plist
	launchctl load /Library/LaunchDaemons/xhyve.lxe.erianna.com.plist

# Uninstalls the image
uninstall:
	rm -rf /Library/Containers/$(IDENTIFIER)/boot
	launchctl unload -w /Library/LaunchDaemons/xhyve.lxe.erianna.com.plist
	rm -rf /Library/LaunchDaemons/xhyve.lxe.erianna.com.plist

# Creates a package of the local image for distribution
package:
	mkdir -p ./ROOT/Library/Containers/$(IDENTIFIER)/ ./ROOT/usr/local/bin/
	cp /usr/local/bin/lxe ./ROOT/usr/local/bin/
	cp /usr/local/bin/xhyve ./ROOT/usr/local/bin/
	cp -R ./boot ./ROOT/Library/Containers/$(IDENTIFIER)/
	cp headless.sh ./ROOT/Library/Containers/$(IDENTIFIER)/
	gzip -9 $(HDD_IMG)
	mv $(HDD_IMG).gz ./ROOT/Library/Containers/$(IDENTIFIER)/
	pkgbuild --root ./ROOT --identifier $(IDENTIFIER) --version $(VERSION) --scripts ./scripts/ $(PKG_NAME)