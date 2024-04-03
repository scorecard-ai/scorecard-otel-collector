set -e

rm -f ocb

# Configure which environment we're building in.
OS=linux
ARCH=amd64
SOURCE_ARCH=x86_64
DEST=build/packages/linux/$ARCH

OCB_VERSION=0.97.0
OCB_URL=`curl https://api.github.com/repos/open-telemetry/opentelemetry-collector/releases | jq -r ".[] | select(.tag_name==\"cmd/builder/v${OCB_VERSION}\") | .assets[] | select(.name==\"ocb_${OCB_VERSION}_${OS}_${ARCH}\") | .browser_download_url"`

curl -L -o ocb $OCB_URL
chmod +x ocb

./ocb --config builder-config.yaml
ARCH=$ARCH SOURCE_ARCH=$SOURCE_ARCH DEST=$DEST ./tools/packaging/linux/create_rpm.sh