ARCH      = x86_64
QEMUARCH  = qemux86-64
VERSION   = 0.0.1

GPG_HOME  = $(TOPDIR)/.gpg.flatpak
KEY_CFG   = repo-key.cfg
KEY_PUB   = repo-key.pub
KEY_SEC   = repo-key.sec

TOPDIR    = $(CURDIR)
SCRIPTS   = $(TOPDIR)/scripts
REPO      = $(TOPDIR)/flatpak.repo
POKY      = $(TOPDIR)/../poky
IMAGEDIR  = $(POKY)/build/tmp/deploy/images
TARDIR    = $(IMAGEDIR)/$(QEMUARCH)

RUNTIME_IMAGE = flatpak-runtime-image
RUNTIME_TAR   = $(TARDIR)/$(RUNTIME_IMAGE)-$(QEMUARCH).tar.bz2
RUNTIME_LIBS  = runtime.libs

SDK_IMAGE     = flatpak-sdk-image
SDK_TAR       = $(TARDIR)/$(SDK_IMAGE)-$(QEMUARCH).tar.bz2
SDK_LIBS      = sdk.libs

all: populate-runtime populate-sdk

populate-runtime: $(KEY_SEC) $(RUNTIME_TAR)
	$(SCRIPTS)/populate-repo.sh --repo $(REPO) \
	    --builddir $(POKY)/build --type runtime --libs $(RUNTIME_LIBS)

$(RUNTIME_TAR):
	pushd $(POKY) && \
	    source ./oe-init-build-env && \
	    bitbake $(RUNTIME_IMAGE) && \
	popd

runtime: populate-runtime


populate-sdk: $(KEY_SEC) $(SDK_TAR) $(SDK_LIBS)
	$(SCRIPTS)/populate-repo.sh --repo $(REPO) \
	    --builddir $(POKY)/build --type sdk --libs $(SDK_LIBS)

$(SDK_TAR):
	pushd $(POKY) && \
	    source ./oe-init-build-env && \
	    bitbake $(SDK_IMAGE) && \
	popd

sdk: populate-sdk


flatpak-repo.conf: flatpak-repo.conf.in
	cat $< | sed 's#@REPO@#$(REPO)#g' > $@
	echo ""
	echo "* Generated configuration file $@."
	echo ""
	echo "* This is an Apache configuration file for exporting your flatpak"
	echo "* repository over HTTP. Please"
	echo "*   - copy it to a location appropriate for your distro"
	echo "        (cp $@ /etc/httpd/conf.d; on Fedora)"
	echo "    - adjust your firewall settings to let HTTP traffic in,"
	echo "        (sudo iptables -t filter -I INPUT -p tcp --dport 80 -j ACCEPT)"
	echo "    - and restart apache"
	echo "        (sudo systemctl restart httpd)"
	echo -e '\a'
	sleep 1
	echo -e '\a'
	sleep 1


$(KEY_PUB) $(KEY_SEC): $(KEY_CFG)
	$(SCRIPTS)/gpg-keygen.sh -H $(GPG_HOME) -c $(KEY_CFG)

clean-keys:
	rm -fr $(GPG_HOME) $(KEY_PUB) $(KEY_SEC)


clean: clean-repo

clean-repo:
	rm -fr $(REPO)

.SILENT:
