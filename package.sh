#!/bin/bash


product=${PACKAGE_PRODUCT}

versions=${PACKAGE_VERSION}

#architectures=(386 amd64 armhf)
if [ -z "${PACKAGE_ARCH}" ];
then
	architectures=(386 amd64 armv6)
else
	architectures=${PACKAGE_ARCH}
fi

if [ -z "${PACKAGE_TARGET}" ];
then
	targets=(rpm deb)
else
	targets=${PACKAGE_TARGET}
fi

build_number=${TRAVIS_BUILD_NUMBER:-1}

checksum_file() {
	local file

	file=$1

	openssl dgst -sha256 ${file} | awk '{print $2}'
}

download_checksums() {
	local product
	local version

        product=$1
	version=$2

	file=${product}_${version}_SHA256SUMS
	download_release_file ${product} ${version} ${file}
	echo "${file}"
}

download_checksums_sig() {
	local product
	local version

        product=$1
	version=$2

	file=${product}_${version}_SHA256SUMS

	download_release_file ${product} ${version} ${file}
}

verify_download() {
	local checksums
	local file

	checksums=$1
	file=$2

	grep ${f} ${checksums} | shasum --status --algorithm 256 --check -
	if [ $? -ne 0 ]; then
		echo "failed to verify checksum for ${file}." > /dev/stderr
		exit 1
	fi
}

download_release_file(){
	local product
	local version
	local file
	product=$1
	version=$2
	file=$3
	url=https://github.com/prometheus/${product}/releases/download/v${version}/${file}

	download_file ${url} ${file}
}
	#${product}-${version}0.13.0.linux-armv7.tar.gz
        #url=https://releases.hashicorp.com/${product}/${version}/${file}

download_file(){
	local url
	local file
	url=$1
	file=$2

        curl --location --fail --silent --output ${file} ${url}
	if [ $? -ne 0 ]; then
		echo "failed to download ${url}" > /dev/stderr
		exit 1
	fi
	echo "${file}"
}

download_raw_file(){
	local product
	local version
	local file
	product=$1
	version=$2
	file=${3}
        url=https://raw.githubusercontent.com/prometheus/${product}/v${version}/${file}

	download_file ${url} $(basename ${file})
}

download_license() {
	local product
	local version

        product=$1
	version=$2

	file=LICENSE

	download_raw_file ${product} ${version} ${file}
}

download_changelog() {
	local product
	local version

        product=$1
	version=$2

	file=CHANGELOG.md

	download_raw_file ${product} ${version} ${file}
}

download_release() {
	local product
	local version
	local arch

	product=$1
	version=$2
	arch=$3

	file="${product}-${version}.linux-${arch}.tar.gz"

	download_release_file ${product} ${version} ${file}
}


package_release(){
        local pkg_type
	local product
	local version
	local arch

	pkg_type=$1
	product=$2
	version=$3
	arch=$4

	package_arch=${arch}
	if [ "${arch}" == "386" ]; then
		package_arch="i386"
	elif [ "${arch}" == "armv6" ]; then
		package_arch="armhf"
	fi

	package_version=${version}-${build_number}
	package_file=${product}_${package_version}_${package_arch}.${pkg_type}

	rm -f ${package_file}

	bundle exec fpm -C ./dist/${product} -t ${pkg_type} -s dir \
    	  --prefix / \
	  --package "${package_file}" \
    	  --name "${product}" \
	  --template-scripts \
	  --before-install scripts/before-install.${pkg_type}.sh \
          --version "${package_version}" \
	  --architecture ${package_arch} \
	  --description "Hashicorp ${product}" \
	  --maintainer "Pat Downey <pat.downey+package-${product}@gmail.com>" \
	  --url "https://github.com/patdowney/package-${product}" \
	  --deb-user ${product} \
	  --deb-group ${product} \
	  --verbose \
	  ../../.build/${product}-${version}/${arch}/${product}=/usr/bin/${product} \
	  ../../.build/${product}-${version}/LICENSE=/usr/share/doc/${product}/ \
	  ../../.build/${product}-${version}/CHANGELOG.md=/usr/share/doc/${product}/ \
	  .

	if [ $? -ne 0 ]; then
		exit 1
	fi
}

for ver in ${versions[@]}
do
	mkdir -p .build/${product}-${ver}
	pushd .build/${product}-${ver}

#        echo "downloading checksums for ${product} ${ver}"
#	checksums=$(download_checksums ${product} ${ver})
#	checksums_sig=$(download_checksums_sig ${product} ${ver})
#	verify_checksum_sig ${checksums} ${f}
	download_license ${product} ${ver}
	download_changelog ${product} ${ver}

        if [[ "${product}" = "nomad" ]]; then
		download_raw_file ${product} ${ver} dist/systemd/nomad.service
	fi

	echo "download version: ${ver}"
	for arch in ${architectures[@]}
	do
		mkdir -p ${arch}
		f=$(download_release ${product} ${ver} ${arch})
		echo ---${f}
		#verify_download ${checksums} ${f}
		pushd ${arch}
                tar zxfv ../${f} --no-anchored ${product} --strip-components 1
		popd
	done
	popd
done

for ver in ${versions[@]}
do
	for arch in ${architectures[@]}
	do
		for target in ${targets[@]}
		do
			package_release ${target} ${product} ${ver} ${arch}
		done
	done
done


