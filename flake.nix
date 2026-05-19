{
  description = "Robin nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    mac-app-util.url = "github:hraban/mac-app-util";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
      mac-app-util,
      nix-homebrew,
    }:
    let
      configuration =
        { pkgs, lib, ... }:
        let
          pgLibPath = lib.makeLibraryPath [
            pkgs.libpq
            pkgs.postgresql
            pkgs.openssl
          ];

        in
        {
          # List packages installed in system profile. To search by name, run:
          # $ nix-env -qaP | grep wget
          environment.systemPackages = [
            # lsp
            pkgs.nixd
            pkgs.nil
            pkgs.nixfmt
            pkgs.taplo
            pkgs.rust-analyzer
            pkgs.ruff
            pkgs.ty

            # tools
            pkgs.fd
            pkgs.ripgrep
            pkgs.rustup
            pkgs.gh
            pkgs.nodejs_22
            pkgs.bun

            # deps for packages
            pkgs.libpq
            pkgs.postgresql
            pkgs.openssl
            pkgs.pkg-config
            pkgs.perl
          ];

          environment.variables = {
            DYLD_LIBRARY_PATH = pgLibPath;
            DYLD_FALLBACK_LIBRARY_PATH = pgLibPath;

            PG_CONFIG = "${pkgs.postgresql}/bin/pg_config";
            PKG_CONFIG_PATH = "${pkgs.libpq.dev}/lib/pkgconfig:${pkgs.openssl.dev}/lib/pkgconfig";

            OPENSSL_DIR = "${pkgs.openssl.dev}";
            OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
            OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";

            PATH = "/Users/rhafid/.bun/bin:$PATH";
          };

          # Symlink nix-managed libraries into /usr/local/lib so the dynamic
          # linker finds them without DYLD_* env vars.
          # macOS SIP strips DYLD_LIBRARY_PATH from children of /bin/zsh & /bin/bash,
          # breaking coding agents (pi, codex, claude-code, etc.).
          # /usr/local/lib is a default dyld fallback search path that SIP can't touch.
          system.activationScripts.postActivation.text = ''
            echo "setting up nix library symlinks in /usr/local/lib..." >&2
            mkdir -p /usr/local/lib

            # Clean old symlinks pointing into the nix store before recreating
            find /usr/local/lib -maxdepth 1 -type l -lname '/nix/store/*' -delete

            for libdir in ${pkgs.libpq}/lib ${pkgs.postgresql.lib}/lib ${pkgs.openssl.out}/lib; do
              for lib in "$libdir"/*.dylib; do
                [ -f "$lib" ] || continue
                name=$(basename "$lib")
                ln -sf "$lib" "/usr/local/lib/$name"
              done
            done
          '';

          fonts.packages = with pkgs; [
            nerd-fonts.fira-code
            fira-code-symbols
          ];

          homebrew = {
            enable = true;
            brews = [ "mole" ];
            casks = [
              "ghostty"
              "steam"
            ];
            onActivation.cleanup = "zap";
          };

          # Necessary for using flakes on this system.
          nix.settings.experimental-features = [
            "nix-command"
            "flakes"
          ];

          # User permissions
          nix.settings.trusted-users = [
            "root"
            "rhafid"
          ];

          # Enable alternative shell support in nix-darwin.
          programs.zsh.enable = true;

          # Set Git commit hash for darwin-version.
          system.configurationRevision = self.rev or self.dirtyRev or null;

          # Primary user
          system.primaryUser = "rhafid";
          security.pam.services.sudo_local.touchIdAuth = true;

          # Used for backwards compatibility, please read the changelog before changing.
          # $ darwin-rebuild changelog
          system.stateVersion = 6;

          # The platform the configuration will be used on.
          nixpkgs.hostPlatform = "aarch64-darwin";
        };
    in
    {
      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#MacBook-Pro
      darwinConfigurations."MacBook-Pro" = nix-darwin.lib.darwinSystem {
        modules = [
          configuration
          mac-app-util.darwinModules.default
          nix-homebrew.darwinModules.nix-homebrew
          {
            nix-homebrew = {
              enable = true;
              enableRosetta = true;
              user = "rhafid";
              autoMigrate = true;
            };
          }
        ];
      };
    };
}
