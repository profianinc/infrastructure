{
  benefice-production,
  benefice-staging,
  benefice-testing,
  enarx,
  ...
}: final: prev: {
  benefice.testing = benefice-testing.packages.x86_64-linux.benefice-debug-x86_64-unknown-linux-musl;
  benefice.staging = benefice-staging.packages.x86_64-linux.benefice-x86_64-unknown-linux-musl;
  benefice.production = benefice-production.packages.x86_64-linux.benefice-x86_64-unknown-linux-musl;

  enarx = enarx.packages.x86_64-linux.enarx-x86_64-unknown-linux-musl;
}
