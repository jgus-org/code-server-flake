{
  description = "code-server: VS Code in the browser (coder/code-server).";

  inputs = {
    flake-lib.url = "github:jgus-org/flake-lib/v1";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    {
      self,
      flake-lib,
      nixpkgs,
    }:
    let
      pin = import ./pin.nix;
      inherit (pin) version;
      # The orchestrator's version-only placeholder pin carries no `hashes` (update-version fills it),
      # so default to {} — the flake must still evaluate enough to expose update-version/update-branches.
      hashes = pin.hashes or { };
      source = {
        owner = "coder";
        repo = "code-server";
        type = "github";
      };

      # nix-system -> upstream tarball os-arch suffix, for the hosts this flake builds for.
      platformSuffix = {
        "aarch64-darwin" = "macos-arm64";
        "aarch64-linux" = "linux-arm64";
        "x86_64-linux" = "linux-amd64";
      };
    in
    # Iterate the standard hosts so update-version/update-branches exist everywhere the orchestrator may
    # reach (it calls them against a hash-less placeholder pin). `code-server` itself is exposed only for
    # the hosts the pinned release actually shipped — upstream drops prebuilt targets over time.
    flake-lib.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        suffix = platformSuffix.${system};

        orgFormatting = flake-lib.lib.mkFormatting {
          inherit self system;
        };

        src = pkgs.fetchurl {
          hash = hashes.${system} or "";
          url = "https://github.com/coder/code-server/releases/download/v${version}/code-server-${version}-${suffix}.tar.gz";
        };

        code-server = pkgs.stdenv.mkDerivation {
          inherit src version;
          dontFixup = true;
          installPhase = ''
            runHook preInstall

            mkdir -p $out
            cp -r . $out/

            # Wrap the binary to find node and set up the environment
            wrapProgram $out/bin/code-server \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.nodejs ]}

            runHook postInstall
          '';
          meta = {
            description = "VS Code in the browser";
            homepage = "https://github.com/coder/code-server";
            mainProgram = "code-server";
            platforms = builtins.attrNames hashes;
          };
          nativeBuildInputs = [ pkgs.makeWrapper ];
          pname = "code-server";
          sourceRoot = "code-server-${version}-${suffix}";
        };

      in
      {
        checks.formatting = orgFormatting.check;
        formatter = orgFormatting.formatter;
        # code-server only for platforms present in the pin; scripts always (the orchestrator needs them).
        packages =
          pkgs.lib.optionalAttrs (hashes ? ${system}) {
            inherit code-server;
            default = code-server;
          }
          // {
            update-branches = flake-lib.lib.mkUpdateBranches {
              inherit pkgs source;
              minimumTrackingVersion = "4.121.0";
              pinSchema = "version-only";
            };
            # Bespoke build (per-platform prebuilt tarball) + bespoke update-version (prefetches the
            # platform matrix into a keyed hash table); only the per-version-branch orchestrator is shared.
            update-version = pkgs.writeShellApplication {
              name = "update-version";
              text = ''exec ${./update-version.sh} "$@"'';
            };
          };
      }
    );
}
