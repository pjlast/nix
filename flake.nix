{
  description = "Petri's flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
  };

  outputs =
    {
      self,
      nix-darwin,
      nixpkgs,
      nix-homebrew,
    }:
    let
      nixosConfiguration =
        { config, pkgs, ... }:
        {
          imports = [
            # Include the results of the hardware scan.
            ./mbp2015hardware-configuration.nix
          ];

          # Bootloader.
          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;

          # Use latest kernel.
          boot.kernelPackages = pkgs.linuxPackages_latest;

          networking.hostName = "mbp2015"; # Define your hostname.
          # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

          # Enable networking
          networking.networkmanager.enable = true;

          # Set your time zone.
          time.timeZone = "Africa/Johannesburg";

          # Select internationalisation properties.
          i18n.defaultLocale = "en_ZA.UTF-8";

          # Enable the GNOME Desktop Environment.
          services.displayManager.gdm.enable = true;

          # Enable CUPS to print documents.
          services.printing.enable = true;

          services.tlp.enable = true;
          services.mbpfan.enable = true;

          # Enable sound with pipewire.
          services.pulseaudio.enable = false;
          security.rtkit.enable = true;
          services.pipewire = {
            enable = true;
            alsa.enable = true;
            alsa.support32Bit = true;
            pulse.enable = true;
            # If you want to use JACK applications, uncomment this
            #jack.enable = true;

            # use the example session manager (no others are packaged yet so this is enabled by default,
            # no need to redefine it in your config for now)
            #media-session.enable = true;
          };

          # Define a user account. Don't forget to set a password with ‘passwd’.
          users.users.pjlast = {
            isNormalUser = true;
            description = "Petri-Johan Last";
            extraGroups = [
              "networkmanager"
              "wheel"
            ];
            packages = with pkgs; [
              adwaita-icon-theme
              gcc
              ghostty
              git
              i3status
              librewolf
              neovim
              tmux
            ];
          };

          # Allow unfree packages
          nixpkgs.config.allowUnfree = true;

          # List packages installed in system profile. To search, run:
          # $ nix search wget
          environment.systemPackages = with pkgs; [
            vim
            grim
            slurp
            wl-clipboard
            mako
          ];

          services.gnome.gnome-keyring.enable = true;

          programs.sway = {
            enable = true;
            wrapperFeatures.gtk = true;
          };

          # Some programs need SUID wrappers, can be configured further or are
          # started in user sessions.
          # programs.mtr.enable = true;
          # programs.gnupg.agent = {
          #   enable = true;
          #   enableSSHSupport = true;
          # };

          # List services that you want to enable:

          # Enable the OpenSSH daemon.
          # services.openssh.enable = true;

          # Open ports in the firewall.
          # networking.firewall.allowedTCPPorts = [ ... ];
          # networking.firewall.allowedUDPPorts = [ ... ];
          # Or disable the firewall altogether.
          # networking.firewall.enable = false;

          # This value determines the NixOS release from which the default
          # settings for stateful data, like file locations and database versions
          # on your system were taken. It‘s perfectly fine and recommended to leave
          # this value at the release version of the first install of this system.
          # Before changing this value read the documentation for this option
          # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
          system.stateVersion = "25.05"; # Did you read the comment?

        };
      darwinConfiguration =
        { pkgs, config, ... }:
        {
          system.primaryUser = "pjlast";

          # List packages installed in system profile. To search by name, run:
          # $ nix-env -qaP | grep wget
          environment.systemPackages = with pkgs; [
            neovim
            tmux
          ];

          # Homebrew
          homebrew = {
            enable = true;
            casks = [
              "adobe-acrobat-reader"
              "anki"
              "ghostty"
              "gimp"
              "google-chrome"
              "whatsapp"
              "zoom"
            ];
          };

          system.activationScripts.applications.text =
            let
              env = pkgs.buildEnv {
                name = "system-applications";
                paths = config.environment.systemPackages;
                pathsToLink = "/Applications";
              };
            in
            pkgs.lib.mkForce ''
              	  # Set up applications.
              	  echo "setting up /Applications..." >&2
              	  rm -rf /Applications/Nix\ Apps
              	  mkdir -p /Applications/Nix\ Apps
              	  find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
              	  while read -r src; do
              	    app_name=$(basename "$src")
              	    echo "copying $src" >&2
              	    ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
              	  done
              	'';

          # Necessary for using flakes on this system.
          nix.settings.experimental-features = "nix-command flakes";

          # Enable alternative shell support in nix-darwin.
          # programs.fish.enable = true;

          # Set Git commit hash for darwin-version.
          system.configurationRevision = self.rev or self.dirtyRev or null;

          # Used for backwards compatibility, please read the changelog before changing.
          # $ darwin-rebuild changelog
          system.stateVersion = 6;

          # The platform the configuration will be used on.
          nixpkgs.hostPlatform = "aarch64-darwin";

          # Allow unfree packages
          nixpkgs.config.allowUnfree = true;
        };
    in
    {
      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#mbp
      darwinConfigurations."mbp" = nix-darwin.lib.darwinSystem {
        modules = [
          darwinConfiguration
          nix-homebrew.darwinModules.nix-homebrew
          {
            nix-homebrew = {
              enable = true;
              enableRosetta = true;
              user = "pjlast";
            };
          }
        ];
      };

      nixosConfigurations."mbp2015" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nixosConfiguration
        ];
      };

      devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
        buildInputs = [
          nixpkgs.legacyPackages.x86_64-linux.nil
        ];
      };
    };
}
