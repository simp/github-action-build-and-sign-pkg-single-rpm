# github-action-build-and-sign-pkg-single-rpm

Build and sign an RPM from the current directory (using `rake pkg:single`)

[![Verify Action](https://github.com/simp/github-action-build-and-sign-pkg-single-rpm/workflows/Verify%20Action/badge.svg)](https://github.com/simp/github-action-build-and-sign-pkg-single-rpm/actions?query=workflow%3A%22Verify+Action%22)
[![tag badge](https://img.shields.io/github/v/tag/simp/github-action-build-and-sign-pkg-single-rpm)](https://github.com/simp/github-action-build-and-sign-pkg-single-rpm/tags)
[![license badge](https://img.shields.io/github/license/simp/github-action-build-and-sign-pkg-single-rpm)](./LICENSE)


<!-- vim-markdown-toc GFM -->

* [Description](#description)
  * [Process](#process)
* [Usage](#usage)
* [Reference](#reference)
  * [Action Inputs](#action-inputs)
  * [Action Outputs](#action-outputs)
  * [:warning: Security implications :warning:](#warning-security-implications-warning)
* [Contributing](#contributing)
* [Feedback & Questions](#feedback--questions)
* [License](#license)

<!-- vim-markdown-toc -->

## Description

A [Github action] to build and sign an RPM using `pkg:single` from simp-core

Note that this requires the **secret (private) GPG signing key** as input;
understand the [security implications](#warning-security-implications-warning)
of this before using the action.

### Process

1. Pulls down SIMP build container
2. Prepares build and signing environment
   1. Copies local build directory into build container
   2. Ensures simp-core is checked out to a specific ref for building
   3. Adds GPG signing key to build container (without touching any
      filesystems)
      *  **IMPORTANT:** see [SECURITY IMPLICATIONS](#warning-security-implications-warning)
   4. Configured GPG signing key to sign non-interactively
3. Builds and signs RPM inside a SIMP build docker container
   1. Runs `rake pkg:single` to build the RPM
   2. Signs RPM with GPG signing key using `rpmsign`
4. Outputs RPM and cleans up
   1. Copies new RPM file back to local filesystem
   2. Ensures container is stopped and removed
   3. Returns information about new RPM file as output variables



## Usage

To safely execute during a `pull_request_target` event, try something like the
following (using a previous **`contributor-permissions`** job to determine if
the Pull Request submitter is trusted):

```yaml
  test_action:
    name: Test build & sign pupmod RPM
    runs-on: ubuntu-18.04
    steps:
      - uses: actions/checkout@v2
        with:
          fetch-depth: 0
          clean: true
      - uses: simp/github-action-build-and-sign-pkg-single-rpm@v1
        name: 'Build & sign RPM'
        id: build-and-sign-rpm
        with:
          gpg_signing_key: ${{ secrets.SIMP_DEV_GPG_SIGNING_KEY }}
          gpg_signing_key_id: ${{ secrets.SIMP_DEV_GPG_SIGNING_KEY_ID }}
          gpg_signing_key_passphrase: ${{ secrets.SIMP_DEV_GPG_SIGNING_KEY_PASSPHRASE }}
          path_to_build: tests/pupmod
      - name: 'Check basic results'
        run: |
          [ -z "$rpm_file_path" ] && { echo '::error ::$rpm_file_path cannot be empty!'; exit 88; }
          [ -z "$rpm_file_basename" ] && { echo '::error ::$rpm_file_basename cannot be empty!'; exit 88; }
          if [ ! -f "$rpm_file_path" ]; then
            printf '::error ::No file found at $rpm_file_path (got "%s")!\n' "$rpm_file_path"
            exit 88
          fi
        env:
          rpm_file_path: ${{ steps.build-and-sign-rpm.outputs.rpm_file_path }}
          rpm_file_basename: ${{ steps.build-and-sign-rpm.outputs.rpm_file_basename }}
```


## Reference


### Action Inputs

<table>
  <thead>
    <tr>
      <th>Input</th>
      <th>Required</th>
      <th>Description</th>
    </tr>
  </thead>

  <tr>
    <td><strong><code>gpg_signing_key</code></strong></td>
    <td>Yes</td>
    <td>ASCII-armored content of the GPG signing key's secret/private key</td>
  </tr>

  <tr>
    <td><strong><code>gpg_signing_key_id</code></strong></td>
    <td>Yes</td>
    <td>GPG signing key's GPG ID (name)</td>
  </tr>

  <tr>
    <td><strong><code>gpg_signing_key_passphrase</code></strong></td>
    <td>Yes</td>
    <td>Passphrase to use the GPG signing key</td>
  </tr>

  <tr>
    <td><strong><code>path_to_build</code></strong></td>
    <td>No</td>
    <td>Path to directory to build<br /><em>Default:</em> <code>${{ github.workspace }}</code></td>
  </tr>

  <tr>
    <td><strong><code>simp_builder_docker_image</code></strong></td>
    <td>No</td>
    <td>SIMP build container image to stage build.  So far, the action has only been tested with (and probably only works with) the EL8 build image'
  <br /><em>Default:</em> <code>docker.io/simpproject/simp_build_centos8:latest</code></td>
  </tr>

  <tr>
    <td><strong><code>simp_core_ref_for_building_rpms</code></strong></td>
    <td>No</td>
    <td>A ref (usually tagged release) in simp-core that is stable enough to build RPMs<br /><em>Default:</em> <code>6.5.0-1</code></td>
  </tr>
</table>


### Action Outputs

<table>
  <thead>
    <tr>
      <th>Output</th>
      <th>Description</th>
    </tr>
  </thead>

  <tr>
    <td><strong><code>rpm_file_path</code></strong></td>
    <td>Local path to the new RPM</td>
  </tr>

  <tr>
    <td><strong><code>rpm_file_basename</code></strong></td>
    <td>Filename of the new RPM</td>
  </tr>
</table>


### :warning: Security implications :warning:

To sign RPMs, the action requires the **secret (aka private) key** of your GPG
signing key **_and_ the passphrase** to decrypt and use it. This inherently
poses [security risks][protecting your private key] that you should be aware of
and understand.

The action does what it can to prevent exposure of the private signing key and
its passphrase; the data never touches the runner's or build container's
filesystems outside of a keyring, and they are handled as environment variables
in a way that should not expose them to the action logs.

However, make sure to:

  * protect your GPG signing key and passphrase as [encrypted GitHub secrets],
    and only provide them directly to the action's inputs.
  * use a GPG signing key that you are comfortable storing and using within
    GitHub's infrastructure.


## Contributing

This is an open source project open to anyone. This project welcomes
contributions and suggestions!

## Feedback & Questions

If you discover an issue, please report it on our Jira at
https://simp-project.atlassian.net/

## License

Apache 2.0, See [LICENSE](https://github.com/simp/github-action-build-and-sign-pkg-single-rpm/blob/main/LICENSE) for more information.



[GitHub action]: https://github.com/features/actions
[protecting your private key]: https://www.gnupg.org/gph/en/manual.html#AEN513
[encrypted GitHub secrets]: https://docs.github.com/en/actions/reference/encrypted-secrets
