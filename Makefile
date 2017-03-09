
PACKAGE_PRODUCT=node_exporter
PACKAGE_VERSION=0.13.0
PACKAGE_ARCH="386 amd64 armv6"

default: package bintray

clean:
	rm -rf .build
	rm -f *.deb *.rpm

bintray:
	cat .bintray/rpm.json.template | sed "s:%%PACKAGE_NAME%%:$(PACKAGE_PRODUCT):g;s:%%PACKAGE_VERSION%%:$(PACKAGE_VERSION):g;" > .bintray/rpm.json
	cat .bintray/deb.json.template | sed "s:%%PACKAGE_NAME%%:$(PACKAGE_PRODUCT):g;s:%%PACKAGE_VERSION%%:$(PACKAGE_VERSION):g;" > .bintray/deb.json

package:
	PACKAGE_PRODUCT=$(PACKAGE_PRODUCT) PACKAGE_VERSION=$(PACKAGE_VERSION) PACKAGE_ARCH=$(PACKAGE_ARCH) bundle exec ./package.sh

