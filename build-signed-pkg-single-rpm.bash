#!/bin/bash -e

PATH_TO_BUILD="${PATH_TO_BUILD:-.}"

if [ ! -d "$PATH_TO_BUILD" ]; then
  # shellcheck disable=SC2016
  printf '::error ::$PATH_TO_BUILD must be a directory (got "%s")!\n' "$PATH_TO_BUILD"
  exit 88
fi
cd "$PATH_TO_BUILD"
rm -rf dist

BUILD_IMAGE="${SIMP_BUILD_IMAGE:-docker.io/simpproject/simp_build_centos8:latest}"
BUILD_CONTAINER=build_el8
BUILD_PATH=/home/build_user/simp-core/_pupmod_to_build
BUILD_PATH_BASENAME="$(basename "$BUILD_PATH")"
RPM_GPG_KEY_EXPORT_NAME="${RPM_GPG_KEY_EXPORT_NAME:-RPM-GPG-KEY-SIMP-UNSTABLE-2}"

# So far we haven't needed to log into the docker registry to pull the image
# but at some point, we probably will:
### docker login "$DOCKER_REGISTRY" -u "$DOCKER_USERNAME" --password-stdin <<< "$DOCKER_PASSWORD"

# Pull down the build container and copy the local directory into it
# ------------------------------------------------------------------------------
docker pull "$BUILD_IMAGE"
docker rm -f "$BUILD_CONTAINER" &> /dev/null || :
docker run --rm -dt --name "$BUILD_CONTAINER" "$BUILD_IMAGE" /bin/bash
docker cp ./ "$BUILD_CONTAINER:$BUILD_PATH"
docker exec "$BUILD_CONTAINER" /bin/bash -c "chown --reference=\"\$(dirname '$BUILD_PATH')\" -R '$BUILD_PATH'"

# 1. Ensure simp-core is checked out to a stable ref for RPM builds
# 2. Build RPM with `rake pkg:single`
# ------------------------------------------------------------------------------
# SIMP pupmod RPMs must be built from simp-core using `rake pkg:single` to
# ensure release-specific dependencies are included
docker exec "$BUILD_CONTAINER" /bin/bash -c \
  "su -l build_user -c 'cd simp-core; git fetch origin; git checkout $SIMP_CORE_REF_FOR_BUILDING_RPMS; bundle; bundle exec rake pkg:single[\$PWD/${BUILD_PATH_BASENAME}]'"

# 1. Add GPG signing key to build container without touching any filesystems
# 2. Set up GPG to sign non-interactively
# 3. Sign RPM
# ------------------------------------------------------------------------------
# (This was so much simpler without GPG signing)

# Add the GPG signing key
# shellcheck disable=SC2016
docker exec -i -e "KEY=$SIMP_DEV_GPG_SIGNING_KEY" "$BUILD_CONTAINER" /bin/bash -c \
  'echo "$KEY" | su -l build_user -c "gpg --batch --import"'

# Set up the preset passphrase
docker exec -i "$BUILD_CONTAINER" /bin/bash -c \
  "su -l build_user -c 'echo allow-preset-passphrase >> ~/.gnupg/gpg-agent.conf; gpg-connect-agent reloadagent /bye'"

# shellcheck disable=SC2016
keygrip_cmd="$(printf 'grp="$(gpg --with-keygrip --with-colons -K "%s" | awk -F: "/grp:/ {print \$10}")"; /usr/libexec/gpg-preset-passphrase --preset %s <<< %s' "$SIMP_DEV_GPG_SIGNING_KEY_ID" '"$grp"' "$(printf "'\$PASS'\n")" )"
docker exec -e "PASS=$SIMP_DEV_GPG_SIGNING_KEY_PASSPHRASE" -i "$BUILD_CONTAINER" /bin/bash -c \
  "su -l build_user -c 'echo allow-preset-passphrase >> ~/.gnupg/gpg-agent.conf ; gpg-connect-agent reloadagent /bye; $keygrip_cmd'"

# Sign the RPM!
# shellcheck disable=SC2016
sign_cmd="$(printf 'rpmsign --define "_gpg_name %s" --define "_gpg_path ~/.gnupg" --resign ' "$SIMP_DEV_GPG_SIGNING_KEY_ID")"

docker exec -i "$BUILD_CONTAINER" /bin/bash -c \
  "su -l build_user -c 'ls -1 $BUILD_PATH/dist/*.rpm | grep -v src.rpm$ | xargs $sign_cmd'"

# Export the GPG key
# shellcheck disable=SC2016
export_cmd="$(printf 'gpg --armor --export "%s" > "%s/dist/%s.pub.asc"' \
  "$SIMP_DEV_GPG_SIGNING_KEY_ID" \
  "$BUILD_PATH" \
  "$RPM_GPG_KEY_EXPORT_NAME" \
)"
echo "== EXPORT CMD: '$export_cmd'"
docker exec -i "$BUILD_CONTAINER" /bin/bash -c \
  "su -l build_user -c 'ls -1 $BUILD_PATH/dist/*.rpm | grep -v src.rpm$ | xargs $export_cmd'"


# Copy RPM back out to local filesystem
# ------------------------------------------------------------------------------
docker cp "$BUILD_CONTAINER:$BUILD_PATH/dist" ./
docker container rm -f "$BUILD_CONTAINER"

# FIXME: doesn't handle multiple RPMs
# shellcheck disable=SC2010
rpm_file="$(ls -1r dist/*.rpm | grep -v 'src\.rpm' | head -1)"
rpm_file_path="$(realpath "$rpm_file")"
gpg_file="$(ls -1r "dist/${RPM_GPG_KEY_EXPORT_NAME}.pub.asc" | head -1)"
gpg_file_path="$(realpath "$gpg_file")"

# Output path of RPM file and the base filename of the RPM
echo "::set-output name=rpm_file_path::$rpm_file_path"
echo "::set-output name=rpm_file_basename::$(basename "$rpm_file_path")"
echo "::set-output name=rpm_dist_dir::$(dirname "$rpm_file_path")"
echo "::set-output name=gpg_file_path::$gpg_file_path"
echo "::set-output name=gpg_file_basename::$(basename "$gpg_file_path")"
echo "Built RPM '$rpm_file_path'"
