# github-action-build-and-sign-pkg-single-rpm

Build and sign an RPM from the current directory (using `rake pkg:single`)

Note that this requires the **secret (private) GPG signing key** as input;
understand the [security implications](#warning-security-implications-warning)
of this before using.


[![Verify Action](https://github.com/simp/github-action-build-and-sign-pkg-single-rpm/workflows/Verify%20Action/badge.svg)](https://github.com/simp/github-action-build-and-sign-pkg-single-rpm/actions?query=workflow%3A%22Verify+Action%22)
[![tag badge](https://img.shields.io/github/v/tag/simp/github-action-build-and-sign-pkg-single-rpm)](https://github.com/simp/github-action-build-and-sign-pkg-single-rpm/tags)
[![license badge](https://img.shields.io/github/license/simp/github-action-build-and-sign-pkg-single-rpm)](./LICENSE)


<!-- vim-markdown-toc GFM -->

* [Description](#description)
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

A [Github action] to build and sign an RPM from the current directory

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
  trigger-when-user-has-repo-permissions:
    name: 'Trigger CI [trusted users only]'
    needs: [ glci-syntax, contributor-permissions ]
    runs-on: ubuntu-18.04
    steps:
      - uses: actions/checkout@v2
        if: needs.contributor-permissions.outputs.permitted == 'true'
        with:
          clean: true
          fetch-depth: 0  # Need full checkout to push to gitlab mirror
          repository: ${{ github.event.pull_request.head.repo.full_name }}
          ref: ${{ github.event.pull_request.head.ref }}

      - name: Trigger CI when user has Repo Permissions
        if: needs.contributor-permissions.outputs.permitted == 'true'
        uses: simp/github-action-build-and-sign-pkg-single-rpm@v1
        with:
          git_branch: ${{ github.event.pull_request.head.ref }}
          git_hashref:  ${{ github.event.pull_request.head.sha }}
          gitlab_api_private_token: ${{ secrets.GITLAB_API_PRIVATE_TOKEN }}
          gitlab_group: ${{ github.event.organization.login }}
          github_repository: ${{ github.repository }}
          github_repository_owner: ${{ github.repository_owner }}

      - name: When user does NOT have Repo Permissions
        if: needs.contributor-permissions.outputs.permitted == 'false'
        continue-on-error: true
        run: |
          echo "Ending gracefully; Contributor $GITHUB_ACTOR does not have permission to trigger CI"
          false

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
    <td>Path to directory to build<br /><em>Default:</em> <code>.</code></td>
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
