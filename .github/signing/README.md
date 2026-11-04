# Signing key for the fork's builds

`debug.keystore` signs every APK built by CI (alias `androiddebugkey`, passwords `android`,
the standard debug-key settings). Without a fixed key each CI run would sign with a new random
key and an update could not be installed over the previous build.

This is a debug key in a public repository: anyone can sign an APK with it. Only install
APKs from this repository's releases. To use a private key instead, store it as a repository
secret and write it to `~/.android/debug.keystore` in the workflow.
