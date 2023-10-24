{
  description = "Description for the project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    devenv.url = "github:cachix/devenv";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    flake-root.url = "github:srid/flake-root";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
    allow-broken = true;
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, nix2container, flake-root, ... }:

    flake-parts.lib.mkFlake { inherit inputs; } (
      { flake-parts-lib, withSystem, ... }: {

        imports = [
          inputs.flake-root.flakeModule
          inputs.devenv.flakeModule
          inputs.treefmt-nix.flakeModule
          ./nix/modules/container.nix
          ./nix/modules/tailwindcss.nix
        ];

        systems = [ "x86_64-linux" "i686-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

        perSystem = { config, self', inputs', pkgs, system, lib, ... }:
          let
            ghc = pkgs.haskell.compiler.ghc946;
            google-cloud-project = "ai-playground-c437";
          in
          {
            flake-root.projectRootFile = "flake.nix";
            _module.args.pkgs = import nixpkgs {
              inherit system;

              config = {
                allowUnfree = true;
              };

              overlays = [
                self.overlays.default
              ];
            };
            # Per-system attributes can be defined here. The self' and inputs'
            # module parameters provide easy access to attributes of the same
            # system.

            # Formatting of all source files
            treefmt.config = import ./treefmt.nix { inherit pkgs config; };

            tailwindcss = {
              src = ./app;
              inputCss = ./app/static/style.css;
              # Pattern relative to src
              content = [
                "./**/*.hs"
                "./templates/**/*"
              ];
              plugins = [
                "@tailwindcss/forms"
                "@tailwindcss/aspect-ratio"
                "@tailwindcss/language-server"
                "@tailwindcss/line-clamp"
                "@tailwindcss/typography"
              ];
            };

            # Deploy to Google Cloud Run
            gcloud-run-deploy-container = {

              project_id = google-cloud-project;
              location = "europe-west3";
              repository-name = "docker";

              pkgs = crossSystem: import nixpkgs {
                inherit crossSystem;
                localSystem = system;

                overlays = [
                  self.overlays.default
                ];
              };

              containers = {

                xhaskell = {
                  image = pkgs: {
                    copyToRoot = [
                      config.packages.xhaskell-static-files
                    ];
                    config = {
                      entrypoint = [ "${lib.getExe pkgs.xhaskell}" ];
                      Env = [
                        "PORT=80"
                        "STATIC_DIR=/var/www"
                      ];
                    };
                    maxLayers = 100;
                  };
                };
              };

            };


            # Development Shell
            devenv.shells.default = {
              name = "xhaskell";

              imports = [
                # This is just like the imports in devenv.nix.
                # See https://devenv.sh/guides/using-with-flake-parts/#import-a-devenv-module
                # ./devenv-foo.nix
              ];

              languages.nix.enable = true;
              languages.haskell = {
                enable = true;
                package = ghc;
                stack = null;
              };

              # https://devenv.sh/reference/options/
              packages = [
                pkgs.haskellPackages.cabal-install
                pkgs.haskellPackages.haskell-language-server
                pkgs.haskellPackages.ghcid

                pkgs.skopeo
                pkgs.google-cloud-sdk
                pkgs.terraform
                config.tailwindcss.build.cli
                config.treefmt.build.wrapper
              ] ++ lib.attrValues config.treefmt.build.programs;

              scripts.prod.exec = "${lib.getExe pkgs.xhaskell}";

              enterShell = ''
                gcloud config set project ${google-cloud-project}
              '';

              env.STATIC_DIR = "${config.devenv.shells.default.env.DEVENV_STATE}/xhaskell/static";

              # Development setup
              process = {
                implementation = "process-compose";
                before = ''
                  echo "Creating $STATIC_DIR"
                  mkdir -p $STATIC_DIR
                '';
              };

              processes = {

                watch-statics.exec = ''
                  cp -r "app/static/" "$STATIC_DIR"
                  ${pkgs.fswatch}/bin/fswatch -0 "app/static/" | while read -d "" event; \
                  do
                    echo "''${event}"
                    cp -r "''${event}" "$STATIC_DIR"
                  done
                '';

                watch-style = {
                  exec = ''
                    set -euo pipefail
                    set -x
                    ${lib.getExe config.tailwindcss.build.cli} \
                      --watch=always \
                      --input "app/static/style.css" \
                      --output "$STATIC_DIR/style.css"
                  '';
                };

                dev = {
                  exec = "ghcid";
                  process-compose = {
                    depends_on.watch-style.condition = "process_started";
                    depends_on.watch-statics.condition = "process_started";
                    readiness_probe = {
                      exec.command = "curl -s http://localhost:8080/";
                      initial_delay_seconds = 2;
                      period_seconds = 30;
                    };
                    shutdown.signal = 2; # SIGINT (Ctrl-C) to ghcid
                  };
                };
              };
            };

            packages.default = pkgs.xhaskell;
            packages.xhaskell = pkgs.xhaskell;
            packages.xhaskell-static-files = pkgs.runCommandLocal "xhaskell-static-files"
              {
                src_dir = ./app/static;
                out_dir = "/var/www";
              } ''
              set -euo pipefail
              mkdir -p $out$out_dir
              cp -v -R $src_dir/. $out$out_dir/
              cp -vf ${config.packages.tailwindcss-output-css} $out$out_dir/${config.packages.tailwindcss-output-css.name}
            '';
            apps.default.program = pkgs.xhaskell;
          };

        flake = {
          overlays.default = import ./package.nix;
        };

      }
    );
}

