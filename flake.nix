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
            # programming
            pkgs.nixd
            pkgs.nil
            pkgs.nixfmt

            # tools
            pkgs.fd
            pkgs.ripgrep
            pkgs.rustup
            pkgs.gh

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
          };

          homebrew = {
            enable = true;
            brews = [ ];
            casks = [ "ghostty" ];
            onActivation.cleanup = "zap";
          };

          # Necessary for using flakes on this system.
          nix.settings.experimental-features = "nix-command flakes";

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
