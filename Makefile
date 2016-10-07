ARCH      = x86_64
QEMUARCH  = qemux86-64
VERSION   = 0.0.1

TOPDIR    = $(CURDIR)
REPO      = $(TOPDIR)/repo
POKY      = $(TOPDIR)/../poky
IMAGEDIR  = $(POKY)/build/tmp/deploy/images

TARDIR      = $(IMAGEDIR)/$(QEMUARCH)
TAR_XFORM   = --transform 's,^./usr,files,S' \
              --transform 's,^./etc,files/etc,S'
TAR_EXCLUDE = --exclude='./[!eu]*'

RUNTIME_IMAGE    = flatpak-runtime-image
RUNTIME_TAR      = $(TARDIR)/$(RUNTIME_IMAGE)-$(QEMUARCH).tar.bz2
RUNTIME_MANIFEST = $(TARDIR)/$(RUNTIME_IMAGE)-$(QEMUARCH).manifest
RUNTIME_BRANCH   = runtime/org.yocto.BasePlatform/$(ARCH)/$(VERSION)
RUNTIME_METADATA = metadata.runtime

SDK_IMAGE        = flatpak-sdk-image
SDK_TAR          = $(TARDIR)/$(SDK_IMAGE)-$(QEMUARCH).tar.bz2
SDK_MANIFEST     = $(TARDIR)/$(SDK_IMAGE)-$(QEMUARCH).manifest
SDK_BRANCH       = runtime/org.yocto.BaseSdk/$(ARCH)/$(VERSION)
SDK_METADATA     = metadata.sdk

TMP_RUNTIME      = .runtime.tmp
TMP_SDK          = .sdk.tmp


all: make-repo populate-runtime populate-sdk runtime.libs

clean: clean-repo

make-repo: flatpak-repo.conf
	if [ ! -d $(REPO) ]; then \
	    echo "Initializing OSTree repo $(REPO)..."; \
	    ostree --repo=$(REPO) init --mode=archive-z2; \
	fi

clean-repo:
	rm -fr $(REPO)

populate-runtime: make-repo $(RUNTIME_TAR)
	rm -fr $(TMP_RUNTIME) && mkdir $(TMP_RUNTIME)
	echo "Populating $(REPO) with runtime image..."
	(cd $(TMP_RUNTIME); \
	    tar $(TAR_XFORM) $(TAR_EXCLUDE) -xvjf $(RUNTIME_TAR) > /dev/null)
	cp $(RUNTIME_MANIFEST) $(TMP_RUNTIME)/files/manifest.base
	find $(TMP_RUNTIME) -type f -name \*.pyc -exec rm -f {} \;
	find $(TMP_RUNTIME) -type f -name \*.pyo -exec rm -f {} \;
	cat $(RUNTIME_METADATA).in | \
	    sed 's/@ARCH@/$(ARCH)/g;s/@VERSION@/$(VERSION)/g' \
	        > $(TMP_RUNTIME)/metadata
	find $(TMP_RUNTIME) -type f -exec chmod u+r {} \;
	ostree --repo=$(REPO) commit \
	    --owner-uid=0 --owner-gid=0 --no-xattrs \
	    --branch=$(RUNTIME_BRANCH) -s "Runtime $(VERSION)" $(TMP_RUNTIME)
	ostree --repo=$(REPO) summary -u
	rm -fr $(TMP_RUNTIME)

$(RUNTIME_TAR):
	pushd $(POKY) && \
	    source ./oe-init-build-env && \
	    bitbake $(RUNTIME_IMAGE) && \
	popd

runtime: populate-runtime

runtime.libs: $(RUNTIME_TAR)
	tar -tjf $(RUNTIME_TAR) | grep 'lib/lib.*\.so\.' > $@


populate-sdk: make-repo $(SDK_TAR)
	rm -fr $(TMP_SDK) && mkdir $(TMP_SDK)
	echo "Populating $(REPO) with SDK image..."
	(cd $(TMP_SDK); \
	    tar $(TAR_XFORM) $(TAR_EXCLUDE) -xvjf $(SDK_TAR) > /dev/null)
	cp $(SDK_MANIFEST) $(TMP_SDK)/files/manifest.base
	find $(TMP_SDK) -type f -name \*.pyc -exec rm -f {} \;
	find $(TMP_SDK) -type f -name \*.pyo -exec rm -f {} \;
	cat $(SDK_METADATA).in | \
	    sed 's/@ARCH@/$(ARCH)/g;s/@VERSION@/$(VERSION)/g' \
	        > $(TMP_SDK)/metadata
	find $(TMP_SDK) -type f -exec chmod u+r {} \;
	ostree --repo=$(REPO) commit \
	    --owner-uid=0 --owner-gid=0 --no-xattrs \
	    --branch=$(SDK_BRANCH) -s "SDK $(VERSION)" $(TMP_SDK)
	ostree --repo=$(REPO) summary -u
	rm -fr $(TMP_SDK)

$(SDK_TAR):
	pushd $(POKY) && \
	    source ./oe-init-build-env && \
	    bitbake $(SDK_IMAGE) && \
	popd

sdk: populate-sdk

flatpak-repo.conf: flatpak-repo.conf.in
	cat $< | sed 's#@PATH@#$(REPO)#g' > $@
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

.SILENT:
