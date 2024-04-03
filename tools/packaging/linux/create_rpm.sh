#!/usr/bin/env bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License is located at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# or in the "license" file accompanying this file. This file is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied. See the License for the specific language governing
# permissions and limitations under the License.

set -e
echo "**********************************************************"
echo "Creating rpm file for Amazon Linux and RHEL, Arch: ${ARCH}"
echo "**********************************************************"

SPEC_FILE="tools/packaging/linux/build.spec"
BUILD_ROOT="$(pwd)/build/rpmbuild"
WORK_DIR="$(pwd)/build/rpmtar"
VERSION=$(cat VERSION)
RPM_NAME=scorecard-otel-collector
SOC_ROOT=${WORK_DIR}/${RPM_NAME}-${VERSION}

echo "Creating rpmbuild workspace"
mkdir -p "${BUILD_ROOT}"/{RPMS,SRPMS,BUILD,SOURCES,SPECS}

echo "Creating file structure"
mkdir -p "${SOC_ROOT}/opt/scorecard/scorecard-otel-collector/logs"
mkdir -p "${SOC_ROOT}/opt/scorecard/scorecard-otel-collector/bin"
mkdir -p "${SOC_ROOT}/opt/scorecard/scorecard-otel-collector/etc"
mkdir -p "${SOC_ROOT}/opt/scorecard/scorecard-otel-collector/var"
mkdir -p "${SOC_ROOT}/opt/scorecard/scorecard-otel-collector/doc"
mkdir -p "${SOC_ROOT}/etc/init"
mkdir -p "${SOC_ROOT}/etc/systemd/system"
mkdir -p "${SOC_ROOT}/usr/bin"
mkdir -p "${SOC_ROOT}/etc/scorecard"
mkdir -p "${SOC_ROOT}/var/log/scorecard"
mkdir -p "${SOC_ROOT}/var/run/scorecard"

echo "Copying application files"
# License, version, release note...
cp LICENSE "${SOC_ROOT}/opt/scorecard/scorecard-otel-collector/"
cp VERSION "${SOC_ROOT}/opt/scorecard/scorecard-otel-collector/bin/"

# binary
cp "scorecard-otel-collector/scorecard-otel-collector" "${SOC_ROOT}/opt/scorecard/scorecard-otel-collector/bin/scorecard-otel-collector"
# ctl
cp tools/ctl/linux/scorecard-otel-collector-ctl.sh "${SOC_ROOT}/opt/scorecard/scorecard-otel-collector/bin/scorecard-otel-collector-ctl"
# default config
cp config.yaml "${SOC_ROOT}/opt/scorecard/scorecard-otel-collector/var/.config.yaml"
# .env
cp .env "${SOC_ROOT}/opt/scorecard/scorecard-otel-collector/etc"
# service config
cp tools/packaging/linux/scorecard-otel-collector.service "${SOC_ROOT}/etc/systemd/system/"
cp tools/packaging/linux/scorecard-otel-collector.conf "${SOC_ROOT}/etc/init/"

echo "assign permission to the files"
chmod ug+rx "${SOC_ROOT}/opt/scorecard/scorecard-otel-collector/bin/scorecard-otel-collector"
chmod ug+rx "${SOC_ROOT}/opt/scorecard/scorecard-otel-collector/bin/scorecard-otel-collector-ctl"
chmod ug+rx "${SOC_ROOT}/opt/scorecard/scorecard-otel-collector/var/.config.yaml"
chmod ug+rx "${SOC_ROOT}/opt/scorecard/scorecard-otel-collector/etc/.env"

echo "create symlinks"
ln -f -s /opt/scorecard/scorecard-otel-collector/bin/scorecard-otel-collector-ctl "${SOC_ROOT}/usr/bin/scorecard-otel-collector-ctl"
ln -f -s /opt/scorecard/scorecard-otel-collector/etc "${SOC_ROOT}/etc/scorecard/scorecard-otel-collector"
ln -f -s /opt/scorecard/scorecard-otel-collector/logs "${SOC_ROOT}/var/log/scorecard/scorecard-otel-collector"
ln -f -s /opt/scorecard/scorecard-otel-collector/var "${SOC_ROOT}/var/run/scorecard/scorecard-otel-collector"

echo "build source tarball"
tar -czvf "${RPM_NAME}-${VERSION}.tar.gz" -C "${WORK_DIR}" .
mv "${RPM_NAME}-${VERSION}.tar.gz" "${BUILD_ROOT}/SOURCES/"
rm -rf "${WORK_DIR}"

echo "Creating the rpm package"
rpmbuild --define "VERSION $VERSION" --define "RPM_NAME $RPM_NAME" --define "_topdir ${BUILD_ROOT}" --define "_source_filedigest_algorithm 8" --define "_binary_filedigest_algorithm 8" -bb -v --clean ${SPEC_FILE} --target "${ARCH}-linux"

echo "Copy rpm file to ${DEST}"
mkdir -p "${DEST}"
cp "${BUILD_ROOT}/RPMS/${ARCH}/${RPM_NAME}-${VERSION}-1.${ARCH}.rpm" "${DEST}/${RPM_NAME}.rpm"
