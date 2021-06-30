#!/bin/bash -e
# ------------------------------------------------------------------------------
# SIMP pupmod RPMs must be built from simp-core using `rake pkg:single` to
# ensure release-specific dependencies are included
# ------------------------------------------------------------------------------


# Pull down the build container and copy the local directory into it
start_build_container()
{
  docker pull "$BUILD_IMAGE"
  docker rm -f "$BUILD_CONTAINER" &> /dev/null || :
  docker run --rm -dt --name "$BUILD_CONTAINER" "$BUILD_IMAGE" /bin/bash
}

copy_local_dir_into_container()
{
  docker cp ./ "$BUILD_CONTAINER:$BUILD_PATH"
  docker exec "$BUILD_CONTAINER" /bin/bash -c "chown --reference=\"\$(dirname '$BUILD_PATH')\" -R '$BUILD_PATH'"
}

# 1. Ensure simp-core is checked out to a stable ref for RPM builds
# 2. Build RPM(s) with `rake pkg:single`
container__build_rpms()
{
  docker exec "$BUILD_CONTAINER" /bin/bash -c \
    "su -l build_user -c 'cd simp-core; git fetch origin; git checkout $SIMP_CORE_REF_FOR_BUILDING_RPMS; bundle; bundle exec rake pkg:single[\$PWD/${BUILD_PATH_BASENAME}]'"
}

# Set up GPG to run non-interactively and sign RPMs
container__setup_gpg_signing_key()
{
  # Add the GPG signing key
  # shellcheck disable=SC2016
  docker exec -i -e "KEY=$SIMP_DEV_GPG_SIGNING_KEY" "$BUILD_CONTAINER" /bin/bash -c \
    'echo "$KEY" | su -l build_user -c "gpg --batch --import"'

  # Set up preset GPG passphrase
  # --------------------------------------
  docker exec -i "$BUILD_CONTAINER" /bin/bash -c \
    "su -l build_user -c 'echo allow-preset-passphrase >> ~/.gnupg/gpg-agent.conf; gpg-connect-agent reloadagent /bye'"

  # shellcheck disable=SC2016
  keygrip_cmd="$(printf 'grp="$(gpg --with-keygrip --with-colons -K "%s" | awk -F: "/grp:/ {print \$10}")"; /usr/libexec/gpg-preset-passphrase --preset %s <<< %s' "$SIMP_DEV_GPG_SIGNING_KEY_ID" '"$grp"' "$(printf "'\$PASS'\n")" )"
  docker exec -e "PASS=$SIMP_DEV_GPG_SIGNING_KEY_PASSPHRASE" -i "$BUILD_CONTAINER" /bin/bash -c \
    "su -l build_user -c 'echo allow-preset-passphrase >> ~/.gnupg/gpg-agent.conf ; gpg-connect-agent reloadagent /bye; $keygrip_cmd'"
}

# GPG Sign the RPMs!
container__gpg_sign_rpms()
{
  # shellcheck disable=SC2016
  sign_cmd="$(printf 'rpmsign --define "_gpg_name %s" --define "_gpg_path ~/.gnupg" --resign ' "$SIMP_DEV_GPG_SIGNING_KEY_ID")"
  docker exec -i "$BUILD_CONTAINER" /bin/bash -c \
    "su -l build_user -c 'ls -1 $BUILD_PATH/dist/*.rpm | xargs $sign_cmd'"
}

# Export the GPG public key
container__export_gpg_public_key()
{
  # shellcheck disable=SC2016
  export_cmd="$(printf 'gpg --armor --export "%s" > "%s/dist/%s.pub.asc"' \
    "$SIMP_DEV_GPG_SIGNING_KEY_ID" \
    "$BUILD_PATH" \
    "$RPM_GPG_KEY_EXPORT_NAME" \
  )"
  docker exec -i "$BUILD_CONTAINER" /bin/bash -c "su -l build_user -c '$export_cmd'"
}

copy_dist_from_container(){ docker cp "$BUILD_CONTAINER:$BUILD_PATH/dist" ./ ; }

remove_build_container(){ docker container rm -f "$BUILD_CONTAINER" ; }

set_github_output_variables()
{
  # shellcheck disable=SC2010
  rpm_file="$(ls -1r dist/*.rpm | grep -v '\.src\.rpm$' | head -1)"
  rpm_file_path="$(realpath "$rpm_file")"
  gpg_file="$(find "dist" -name "${RPM_GPG_KEY_EXPORT_NAME}.pub.asc" | head -1)"
  export gpg_file_path=''
  gpg_file_path="$(realpath "$gpg_file")"

  rpm_file_paths="$(find "$PWD/dist" -name \*.rpm)"
  rpm_file_paths_count="$(echo "$rpm_file_paths" | wc -l)"

  rpm_file_paths="${rpm_file_paths//'%'/'%25'}"
  rpm_file_paths="${rpm_file_paths//$'\n'/'%0A'}"
  rpm_file_paths="${rpm_file_paths//$'\r'/'%0D'}"

  # v1.1.0 (for v2)
  echo "::set-output name=rpm_file_paths::$rpm_file_paths"
  echo "::set-output name=rpm_gpg_file::$(realpath "$gpg_file")"

  # v1.1.0 (deprecated in v2)
  echo "::set-output name=rpm_dist_dir::$(dirname "$rpm_file_path")"

  # Output path of RPM file and the base filename of the RPM
  # v1.0.0 (deprecated in v2)
  echo "::set-output name=rpm_file_path::$rpm_file_path"
  echo "::set-output name=rpm_file_basename::$(basename "$rpm_file_path")"

  echo "Built ${rpm_file_paths_count} RPMs: "
  echo "$rpm_file_paths" | tr '|' '\n' | sed -e 's/^/    /'
  echo
  echo "GPG public key: ${gpg_file_path}"
}


# ------------------------------------------------------------------------------
# main
# ------------------------------------------------------------------------------

PATH_TO_BUILD="${PATH_TO_BUILD:-.}"
BUILD_IMAGE="${SIMP_BUILD_IMAGE:-docker.io/simpproject/simp_build_centos8:latest}"
BUILD_CONTAINER=build_el8
BUILD_PATH=/home/build_user/simp-core/_pupmod_to_build
BUILD_PATH_BASENAME="$(basename "$BUILD_PATH")"
RPM_GPG_KEY_EXPORT_NAME="${RPM_GPG_KEY_EXPORT_NAME:-RPM-GPG-KEY-SIMP-UNSTABLE-2}"

# So far we haven't needed to log into the docker registry to pull the image
# but at some point, we probably will:
### docker login "$DOCKER_REGISTRY" -u "$DOCKER_USERNAME" --password-stdin <<< "$DOCKER_PASSWORD"

if [ ! -d "$PATH_TO_BUILD" ]; then
  # shellcheck disable=SC2016
  printf '::error ::$PATH_TO_BUILD must be a directory (got "%s")!\n' "$PATH_TO_BUILD"
  exit 88
fi
cd "$PATH_TO_BUILD"  # start in local project dir
rm -rf dist          # remove all previous builds

start_build_container
copy_local_dir_into_container
container__build_rpms
container__setup_gpg_signing_key
container__gpg_sign_rpms
container__export_gpg_public_key
copy_dist_from_container  # Copy dist/ (RPMs and GPG public key) back out to local filesystem
remove_build_container
set_github_output_variables
