# Releasing dogstatsd-ruby

Releases use the manually triggered [Publish workflow](https://github.com/DataDog/dogstatsd-ruby/actions/workflows/publish.yml)
on `master`.

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
