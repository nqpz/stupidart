<img src="cosmos.jpg" width="300" height="534" align="right">

# Stupid art

[![Build Status](https://travis-ci.org/nqpz/stupidart.svg?branch=master)](https://travis-ci.org/nqpz/stupidart)

Approximate an input image by adding random shapes on top of each other
in parallel.

Dependencies:

  - [Futhark](http://futhark-lang.org/)

Optional dependencies:

  - SDL2 and SDL2-ttf
  - [FreeImage](http://freeimage.sourceforge.net/)

## Building

To build, first run `futhark pkg sync` once.

Then run `make` to build.

  - To build without the SDL dependency, instead run
    `STUPIDART_NO_INTERACTIVE=1 make`.

  - To build without the FreeImage dependency, instead run
    `STUPIDART_NO_FREEIMAGE=1 make`.  This means you will only be able
    to read and write images in the Netpbm PAM format.  You can use
    ImageMagick's `convert` utility to convert from and to this format.

  - You can also use the backend-specific `LYS_*` environment variables
    mentioned in [Lys](https://github.com/diku-dk/lys) before `make`.

## Running

Run `./stupidart <input image> <output image>` to generate art.

Run `./stupidart --help` to see the available options.

## Controls for interactive use

Unless you run `stupidart -I`, you will watch the image as it is
generated (note that this is slower than the non-interactive approach due to some
internals).

  - `1`: Generate random shapes (default)
  - `2`: Generate only triangles
  - `3`: Generate only circles
  - `4`: Generate only rectangles
  - `r`: Reset
  - Space: Pause/unpause
  - F1: Toggle showing the text.
  - ESC: Save the current image (always without the text) to the output
    file and exit.
