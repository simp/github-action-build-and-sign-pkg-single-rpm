#!/bin/bash -e
# ------------------------------------------------------------------------------
# SIMP pupmod RPMs must be built from simp-core using `rake pkg:single` to
# ensure release-specific dependencies are included
# ------------------------------------------------------------------------------

# Pull down the build container and copy the local directory into it
start_container()
{
  local image="$1"
  local container_name="$2"
  "$CONTAINER_EXE" pull "$image"
  "$CONTAINER_EXE" rm -f "$container_name" &> /dev/null || :
  "$CONTAINER_EXE" run --rm -dt --name "$container_name" "$image" /bin/bash
}


copy_local_dir_into_container()
{
  local container_name="$1"
  local build_path="$2"
  "$CONTAINER_EXE" cp ./ "$container_name:$build_path"
  "$CONTAINER_EXE" exec "$container_name" /bin/bash -c "chown --reference=\"\$(dirname '$build_path')\" -R '$build_path'"
}

# 1. Ensure simp-core is checked out to a stable ref for RPM builds
# 2. Build RPM(s) with `rake pkg:single`
container__build_rpms()
{
  local container_name="$1"
  "$CONTAINER_EXE" exec \
    -e "SIMP_RAKE_PKG_verbose=$SIMP_RAKE_PKG_verbose" \
    -e "SIMP_PKG_verbose=$SIMP_PKG_verbose" \
    "$container_name" /bin/bash -c \
    "su -l build_user -c 'cd simp-core; git fetch origin; git checkout $SIMP_CORE_REF_FOR_BUILDING_RPMS; bundle; bundle update --conservative simp-rake-helpers; bundle exec rake pkg:single[\$PWD/${BUILD_PATH_BASENAME}]'"
}

# Set up GPG to run non-interactively and sign RPMs
container__setup_gpg_signing_key()
{
  local container_name="$1"

  # Add the GPG signing key
  # shellcheck disable=SC2016
  "$CONTAINER_EXE" exec -i -e "KEY=$SIMP_DEV_GPG_SIGNING_KEY" "$container_name" /bin/bash -c \
    'echo "$KEY" | su -l build_user -c "gpg --batch --import"'

  # Set up preset GPG passphrase
  # --------------------------------------
  "$CONTAINER_EXE" exec -i "$container_name" /bin/bash -c \
    "su -l build_user -c 'echo allow-preset-passphrase >> ~/.gnupg/gpg-agent.conf; gpg-connect-agent reloadagent /bye'"

  # shellcheck disable=SC2016
  keygrip_cmd="$(printf 'grp="$(gpg --with-keygrip --with-colons -K "%s" | awk -F: "/grp:/ {print \$10}")"; /usr/libexec/gpg-preset-passphrase --preset %s <<< %s' "$SIMP_DEV_GPG_SIGNING_KEY_ID" '"$grp"' "$(printf "'\$PASS'\n")" )"
  "$CONTAINER_EXE" exec -e "PASS=$SIMP_DEV_GPG_SIGNING_KEY_PASSPHRASE" -i "$container_name" /bin/bash -c \
    "su -l build_user -c 'echo allow-preset-passphrase >> ~/.gnupg/gpg-agent.conf ; gpg-connect-agent reloadagent /bye; $keygrip_cmd'"
}

# GPG Sign the RPMs!
container__gpg_sign_rpms()
{
  local container_name="$1"
  local build_path="$2"

  # shellcheck disable=SC2016
  sign_cmd="$(printf 'rpmsign --define "_gpg_name %s" --define "_gpg_path ~/.gnupg" --resign ' "$SIMP_DEV_GPG_SIGNING_KEY_ID")"
  "$CONTAINER_EXE" exec -i "$container_name" /bin/bash -c \
    "su -l build_user -c 'ls -1 $build_path/dist/*.rpm | xargs $sign_cmd'"
}

# Export the GPG public key
container__export_gpg_public_key()
{
  local container_name="$1"
  local build_path="$2"

  # shellcheck disable=SC2016
  export_cmd="$(printf 'gpg --armor --export "%s" > "%s/dist/%s.pub.asc"' \
    "$SIMP_DEV_GPG_SIGNING_KEY_ID" \
    "$build_path" \
    "$RPM_GPG_KEY_EXPORT_NAME" \
  )"
  "$CONTAINER_EXE" exec -i "$container_name" /bin/bash -c "su -l build_user -c '$export_cmd'"
}

copy_dist_from_container(){
  local container_name="$1"
  local build_path="$2"
  "$CONTAINER_EXE" cp "$container_name:$build_path/dist" ./
}

remove_container(){
  local container_name="$1"
  "$CONTAINER_EXE" container rm -f "$container_name"
}

set_github_output_variables()
{
  # shellcheck disable=SC2010
  rpm_file="$(ls -1 dist/*.rpm | grep -v '\.src\.rpm$' | head -1)"
  rpm_file_path="$(realpath "$rpm_file")"
  gpg_file="$(find "dist" -name "${RPM_GPG_KEY_EXPORT_NAME}.pub.asc" | head -1)"
  export gpg_file_path=''
  gpg_file_path="$(realpath "$gpg_file")"

  rpm_file_paths="$(ls -1 "$PWD"/dist/*.rpm)"
  rpm_file_paths_count="$(echo "$rpm_file_paths" | wc -l)"

  # Prep to output array on a single line for GHA variable
  gha_rpm_file_paths="${rpm_file_paths//'%'/'%25'}"
  gha_rpm_file_paths="${gha_rpm_file_paths//$'\n'/'%0A'}"
  gha_rpm_file_paths="${gha_rpm_file_paths//$'\r'/'%0D'}"

  echo "::set-output name=rpm_file_paths::$gha_rpm_file_paths"
  echo "::set-output name=rpm_gpg_file::$(realpath "$gpg_file")"
  echo "::set-output name=rpm_dist_dir::$(dirname "$rpm_file_path")"

  echo "Built ${rpm_file_paths_count} RPMs: "
  echo "$rpm_file_paths" | tr '|' '\n' | sed -e 's/^\//    /'
  echo
  echo "GPG public key: ${gpg_file_path}"
}


# ------------------------------------------------------------------------------
# main
# ------------------------------------------------------------------------------


CONTAINER_EXE="${CONTAINER_EXE:-docker}"
PATH_TO_BUILD="${PATH_TO_BUILD:-.}"
BUILD_IMAGE="${SIMP_BUILD_IMAGE:-docker.io/simpproject/simp_build_centos8:latest}"
SIGNING_IMAGE="${SIMP_SIGNING_IMAGE:-docker.io/simpproject/simp_build_centos8:latest}"
BUILD_CONTAINER=simp_pkg_builder
BUILD_PATH=/home/build_user/simp-core/_pupmod_to_build
BUILD_PATH_BASENAME="$(basename "$BUILD_PATH")"
SIGNING_CONTAINER=sign_el8
RPM_GPG_KEY_EXPORT_NAME="${RPM_GPG_KEY_EXPORT_NAME:-RPM-GPG-KEY-SIMP-UNSTABLE-2}"
SIMP_RAKE_PKG_verbose="${SIMP_RAKE_PKG_verbose:-no}"
SIMP_PKG_verbose="${SIMP_PKG_verbose:-no}"

# So far we haven't needed to log into the docker registry to pull the image
# but at some point, we probably will:
### "$CONTAINER_EXE" login "$DOCKER_REGISTRY" -u "$DOCKER_USERNAME" --password-stdin <<< "$DOCKER_PASSWORD"

if [ ! -d "$PATH_TO_BUILD" ]; then
  # shellcheck disable=SC2016
  printf '::error ::$PATH_TO_BUILD must be a directory (got "%s")!\n' "$PATH_TO_BUILD"
  exit 88
fi
cd "$PATH_TO_BUILD"  # start in local project dir
rm -rf dist          # remove all previous builds

start_container "$BUILD_IMAGE" "$BUILD_CONTAINER"
copy_local_dir_into_container "$BUILD_CONTAINER" "$BUILD_PATH"

container__build_rpms "$BUILD_CONTAINER"
copy_dist_from_container "$BUILD_CONTAINER" "$BUILD_PATH"
remove_container "$BUILD_CONTAINER"

start_container "$SIGNING_IMAGE" "$SIGNING_CONTAINER"
copy_local_dir_into_container "$SIGNING_CONTAINER" "$BUILD_PATH"
container__setup_gpg_signing_key "$SIGNING_CONTAINER"
container__gpg_sign_rpms "$SIGNING_CONTAINER" "$BUILD_PATH"
container__export_gpg_public_key "$SIGNING_CONTAINER" "$BUILD_PATH"
copy_dist_from_container "$SIGNING_CONTAINER" "$BUILD_PATH"
remove_container "$SIGNING_CONTAINER"

set_github_output_variables
