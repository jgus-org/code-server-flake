# code-server-flake

A Nix flake that packages [code-server](https://github.com/coder/code-server), VS Code in the browser, from upstream's prebuilt release tarballs. Nothing is compiled here: the pinned release's asset for your host is unpacked and its launcher wrapped.

## Outputs

- `packages.<system>.code-server` — the server, launched by `bin/code-server`. `packages.<system>.default` is the same derivation.
- `packages.<system>.update-version`, `packages.<system>.update-branches` — maintenance outputs that move the pin and the version branches. Neither is needed to consume the flake.
- `formatter`, `checks.<system>.formatting` — this repository's own files.

## Consuming

```nix
# flake.nix
{
  inputs.code-server = {
    url = "github:jgus-org/code-server-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # ...
  environment.systemPackages = [ inputs.code-server.packages.${system}.default ];
}
```

Following `nixpkgs` is optional. It changes only which `nodejs` the launcher puts on `PATH` for child processes — see [Runtime](#runtime) — not the server's own interpreter.

There is no `nixosModule`: running code-server as a service means supplying a user, a state directory and a port yourself.

## Which hosts publish a package

The flake iterates `aarch64-darwin`, `aarch64-linux` and `x86_64-linux`, but publishes `packages.<system>` only for the hosts the pinned release actually shipped a prebuilt asset for, and upstream retires targets over time. Ask the flake rather than assuming: `nix flake show` lists what the current pin carries, and `meta.platforms` names exactly those hosts.

The iteration deliberately covers every standard host so the maintenance outputs exist wherever the per-version-branch orchestrator reaches them; those need no asset.

## Runtime

**Two Node runtimes, and the wrapper is not the one that runs the server.** Upstream's tarball bundles its own interpreter at `$out/lib/node`, and upstream's launcher execs that binary directly. This flake additionally wraps `bin/code-server` to put the flake's nixpkgs `nodejs` at the front of `PATH`, which serves child processes — an extension host shell, a terminal, `npm` — while the server itself keeps upstream's bundled Node. Do not expect a nixpkgs bump to change the server's interpreter, or the bundled one to be patched by Nix.

**Prebuilt bytes.** The asset is unpacked with fixup disabled, so its native helpers are upstream's, not rebuilt against Nix's libraries. `x86_64-darwin` is not iterated at all: the host list comes from flake-lib and follows nixpkgs' supported set.

**State.** code-server writes its configuration and extension data under `~/.local/share/code-server` and `~/.config/code-server` unless told otherwise; a service run needs a writable home for its user.

## Maintenance

Version selection, asset hashes and version branches are generated. See flake-lib's `docs/update-workflows.md`; do not hand-edit `pin.nix`.

See [LICENSE.md](LICENSE.md) for licensing and copyright.
