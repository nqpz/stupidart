# You can run nix-shell in this directory if you have Nix installed.

with import <nixpkgs> {};
stdenv.mkDerivation {
    name = "stupidart";
    buildInputs = [ pkgconfig SDL2 SDL2_ttf freeimage ocl-icd opencl-headers ];
}
