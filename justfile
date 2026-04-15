tangle:
  nix develop . --command bash -c "emacs --batch -l ./tangle-script.el"

clean:
  rm init.el
