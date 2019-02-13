#!/bin/sh
if [ -z "$2" ]; then
  echo "Arguments are missing. Please run this script as follows:"
  echo "    ${0} [VERSION] [BINARY_URL] (REVISION)"
  echo "where:"
  echo "    [VERSION] is the EZproxy version number (required)"
  echo "    [BINARY_URL] is the URL to its Linux executable (required)"
  echo "    (REVISION) is the package revision (optional, defaults to 1)"
  echo ""
  exit 1
fi

if [ -z "$3" ]; then
  revision="1"
else
  revision="$3"
fi

packageversion="${1}-${revision}"
target="ezproxy_${packageversion}"
fulltarget="${PWD}/${target}"
configfile="${fulltarget}/etc/ezproxy/config.txt"

echo "The following EZproxy package will be built:"
echo "EZproxy version number: ${1}"
echo "Package version number: ${packageversion}"
echo "Binary URL: ${2}"
echo "'${fulltarget}' will be used as a temporary directory for building."
echo "NOTE: if exists, the aforementioned directory will be removed before proceding!"
read -p "Is this correct? Y/N " answer
echo ""
echo ""

case $answer in
  [Yy] ) break;;
  * ) exit;;
esac

if [ -e "${fulltarget}" ]; then
  echo "Removing existing target directory '${target}'..."
  rm -Rf ${fulltarget}
fi

echo "Recreating the target directory '${target}' and its structure..."
cp -r skel "${fulltarget}"
mkdir -p "${fulltarget}/etc/ezproxy"
mkdir -p "${fulltarget}/usr/bin"
mkdir -p "${fulltarget}/var/lib/ezproxy"
mkdir -p "${fulltarget}/var/log/ezproxy"

echo "Downloading the ezproxy executable..."
wget "${2}" -O "${fulltarget}/usr/bin/ezproxy.real" -q --show-progress

echo "Chmod'ing the ezproxy executable..."
chmod +x "${fulltarget}/usr/bin/ezproxy.real"

echo "Running ezproxy to re-create missing files in its future configuration directory..."
${fulltarget}/usr/bin/ezproxy.real -d ${fulltarget}/etc/ezproxy -m > /dev/null

echo "Making config files group-readable..."
chmod -R g+rX ${fulltarget}/etc/ezproxy

logfilelines="$(grep -c '^LogFile' "${configfile}")"
if [ "${logfilelines}" -ne "0" ]; then
  echo "Changing log location to '/var/log/ezproxy' in future config..."
  sed -i "s/^LogFile.*/LogFile -strftime \/var\/log\/ezproxy\/ezp%Y%m.log/g" "${configfile}"
else
  echo "Setting log location to '/var/log/ezproxy' in future config..."
  echo "\nLogFile -strftime /var/log/ezproxy/ezp%Y%m.log" >> "${configfile}"
fi

echo "Updating package control file..."
sed -i "s/%VERSION%/${packageversion}/g" "${fulltarget}/DEBIAN/control"
sed -i "s/%MAINTAINER%/$(whoami)@localhost/g" "${fulltarget}/DEBIAN/control"

echo "Generating a list of conffiles..."
find ${fulltarget}/etc/ -type f | sort | sed "s|${fulltarget}||g" > ${fulltarget}/DEBIAN/conffiles

echo "Building the package..."
fakeroot dpkg-deb --build ${target}

