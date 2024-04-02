set -e

rm -f ocb

# Configure which environment we're building in.
OS=darwin
ARCH=arm64

OCB_VERSION=0.97.0
OCB_URL=`curl https://api.github.com/repos/open-telemetry/opentelemetry-collector/releases | jq -r ".[] | select(.tag_name==\"cmd/builder/v${OCB_VERSION}\") | .assets[] | select(.name==\"ocb_${OCB_VERSION}_${OS}_${ARCH}\") | .browser_download_url"`

curl -L -o ocb $OCB_URL
chmod +x ocb

./ocb --config builder-config.yaml
