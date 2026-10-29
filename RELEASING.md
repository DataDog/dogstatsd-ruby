# Releasing dogstatsd-ruby

Releases use the manually triggered [Publish workflow](https://github.com/DataDog/dogstatsd-ruby/actions/workflows/publish.yml)
on `master`, following the trusted-publishing flow in
[libdatadog-rb](https://github.com/DataDog/libdatadog-rb/blob/main/.github/workflows/build.yml).
RubyGems authentication uses short-lived OIDC credentials rather than a stored API key.

## Publisher configuration

Register a [trusted publisher](https://guides.rubygems.org/trusted-publishing/adding-a-publisher/)
for the `dogstatsd-ruby` gem on RubyGems.org with:

- Repository owner: `DataDog`
- Repository name: `dogstatsd-ruby`
- Workflow filename: `publish.yml`
- Environment: `rubygems.org`

The GitHub `rubygems.org` environment must allow deployments from `master`
and require release approval. The Octo STS `self.publish` policy grants the
publish job a short-lived GitHub token to push the release tag. Its GitHub App
must have permission to create tags under the repository's tag protection rules.

## Release procedure

1. Update `lib/datadog/statsd/version.rb` and `CHANGELOG.md`, and merge the
   release changes into `master`.
2. Confirm that the Ruby Test workflow passes for the release commit.
3. Run the Publish workflow, selecting `master`, and approve its deployment
   to the `rubygems.org` environment.
4. Confirm that the workflow succeeds and the version is available on
   [RubyGems.org](https://rubygems.org/gems/dogstatsd-ruby).

The workflow runs the specs, then invokes `rubygems/release-gem` using the
existing Bundler `release` task. It builds the gem, creates and pushes its
`v<version>` tag, publishes it with Sigstore provenance, and waits for it to
be available on RubyGems.org. Do not create the release tag beforehand.
