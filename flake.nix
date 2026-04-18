{
  description = "Emacs with nix-community overlay";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    overlay.url = "github:nix-community/emacs-overlay";
  };
  outputs = { self, nixpkgs, overlay, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        system = system;
        overlays = [ (import overlay) ];
      };
      emacsWrapper = pkgs.writeShellScriptBin "emacs-wrapper" ''
        #!/bin/sh
        CACHE_DIR="$HOME/.local/share/emc/"
        mkdir -p "$CACHE_DIR"
        cp -ra ${toString ./.}/* "$CACHE_DIR/" 2>/dev/null || true
        chmod -R u+w "$CACHE_DIR"/*
        export PATH="${pkgs.cmake}/bin:$PATH"
        export PATH="${pkgs.gnumake}/bin:$PATH"
        export PATH="${pkgs.gcc}/bin:$PATH"
        export PATH="${pkgs.libtool}/bin:$PATH"
        export PATH="${pkgs.R}/bin:$PATH"
        cd "$CACHE_DIR"
        ${pkgs.emacs-unstable}/bin/emacs --batch -l ./tangle-script.el 
        exec ${pkgs.emacs-unstable}/bin/emacs --init-dir "$CACHE_DIR" --chdir $HOME "$@"
      '';
    in
    {
      packages.${system}.default = pkgs.emacs-unstable;
      apps.${system}.default = {
        type = "app";
        program = "${emacsWrapper}/bin/emacs-wrapper";
      };
      devShell = pkgs.mkShell {
        buildInputs = [
	  pkgs.emacs-unstable
	  pkgs.nerd-fonts.ubuntu-mono
	  pkgs.libvterm
	  pkgs.tree-sitter
	  pkgs.cmake
	  pkgs.gnumake
	  pkgs.gcc
	  pkgs.libtool
	  pkgs.R
	  pkgs.copilot-language-server
	  ];

      };
    };
}
