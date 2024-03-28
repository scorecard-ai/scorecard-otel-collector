set -e

rm -f ocb

OCB_VERSION=0.96.0
OCB_URL=`curl https://api.github.com/repos/open-telemetry/opentelemetry-collector/releases | jq -r ".[] | select(.tag_name==\"cmd/builder/v${OCB_VERSION}\") | .assets[] | select(.name==\"ocb_${OCB_VERSION}_darwin_arm64\") | .browser_download_url"`

curl -L -o ocb $OCB_URL
chmod +x ocb

./ocb --config builder-config.yaml
