#define _XOPEN_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <assert.h>

#ifndef STUPIDART_NO_INTERACTIVE
#include "lib/github.com/diku-dk/lys/sdl/liblys.h"
#else
#include "lib/github.com/diku-dk/lys/shared.h"
#endif

#include <unistd.h>
#include <getopt.h>

#define MAX_FPS 60
#define FONT_SIZE 20

#ifndef STUPIDART_NO_FREEIMAGE
#include <FreeImage.h>
#include "freeimage_stupidart.h"

uint32_t* image_load(const char* filename, FILE *f, unsigned int *width, unsigned int *height) {
  return (uint32_t*)freeimage_load(filename, f, width, height);
}

void image_save(const char* filename, FILE* f, const uint32_t* image,
                unsigned int width, unsigned int height) {
  freeimage_save(filename, f, (int32_t*)image, width, height);
}
#else
#include "pam.h"

uint32_t* image_load(const char* filename, FILE *f,
                     unsigned int *width, unsigned int *height) {
  (void) filename;
  return pam_load(f, width, height);
}

void image_save(const char* filename, FILE* f, const uint32_t* image,
                unsigned int width, unsigned int height) {
  (void) filename;
  pam_save(f, image, width, height);
}
#endif

uint32_t* run_noninteractive(struct futhark_context *futctx,
                             int width, int height, int seed,
                             int n_max_iterations, float diff_goal,
                             struct futhark_u32_2d *image_fut) {
  struct futhark_u32_2d *output_image_fut;
  uint32_t* output_image_data = (uint32_t*) malloc(width * height * sizeof(int32_t));
  if (output_image_data == NULL) {
    return NULL;
  }
  int n_iterations;
  float diff;
  futhark_entry_noninteractive(futctx, &output_image_fut, &n_iterations, &diff,
                               seed, n_max_iterations, diff_goal, image_fut);
  FUT_CHECK(futctx, futhark_values_u32_2d(futctx, output_image_fut, output_image_data));
  FUT_CHECK(futctx, futhark_free_u32_2d(futctx, output_image_fut));
  fprintf(stderr, "Final number of iterations: %d\nFinal difference: %f%%\n", n_iterations, diff);
  return output_image_data;
}

#ifndef STUPIDART_NO_INTERACTIVE
struct internal {
  TTF_Font *font;
  bool show_text;
};

void loop_iteration(struct lys_context *ctx, struct internal *internal) {
  if (internal->show_text) {
    float diff_percent;
    bool auto_reset;
    char buffer[50];
    FUT_CHECK(ctx->fut, futhark_entry_text_content(ctx->fut, &diff_percent, &auto_reset, ctx->state));
    sprintf(buffer, "Difference: %2.8f%%\nAuto reset: %s", diff_percent, auto_reset ? "on" : "off");
    draw_text(ctx, internal->font, FONT_SIZE, buffer,
              0xff00ffff, 10, 10);

    char instructions[] = "Pick shape: 1-4 | Reset: r\nHide text:  F1  | Quit:  Esc\n                | Pause: Space";
    draw_text(ctx, internal->font, FONT_SIZE, instructions,
              0xffff00ff, ctx->height - FONT_SIZE * 3 - 10, 10);

  }
}

void handle_event(struct lys_context *ctx, enum lys_event event) {
  struct internal *internal = (struct internal *) ctx->event_handler_data;
  switch (event) {
  case LYS_LOOP_ITERATION:
    loop_iteration(ctx, internal);
    break;
  case LYS_F1:
    internal->show_text = !internal->show_text;
  default:
    return;
  }
}

uint32_t* run_interactive(struct futhark_context *futctx,
                          int width, int height, int seed,
                          bool show_text_initial,
                          struct futhark_u32_2d *image_fut) {
  struct lys_context ctx;
  lys_setup(&ctx, width, height, MAX_FPS, 0);
  ctx.fut = futctx;

  ctx.event_handler_data = NULL;
  ctx.event_handler = handle_event;

  futhark_entry_init(ctx.fut, &ctx.state, seed, image_fut);

  futhark_free_u32_2d(ctx.fut, image_fut);

  SDL_ASSERT(TTF_Init() == 0);

  struct internal internal;
  ctx.event_handler_data = (void*) &internal;
  internal.show_text = show_text_initial;
  internal.font = TTF_OpenFont("NeomatrixCode.ttf", FONT_SIZE);
  SDL_ASSERT(internal.font != NULL);

  lys_run_sdl(&ctx);

  TTF_CloseFont(internal.font);

  return ctx.data;
}
#endif

void print_help(char** argv) {
  fprintf(stderr, "Usage: %s [options...] <input image> <output image>\n", argv[0]);
  fputs("\n", stderr);
  fputs("Read an image, iterate on it, and and save it after closing the window.\n", stderr);
  fputs("\n", stderr);
  fputs("Options:\n", stderr);
#ifndef STUPIDART_NO_INTERACTIVE
  fputs("  -I       Do not run interactively.\n", stderr);
#endif
  fputs("  -m N     Set the maximum number of iterations to run.  Default: 1000.\n", stderr);
  fputs("  -g 0..1  Set the goal difference (lower is better).  Default: 0.05.\n", stderr);
  fputs("  -T       Do not show debug text (when interactive).\n", stderr);
  fputs("  -s SEED  Set the seed.\n", stderr);
  fputs("  -d DEV   Set the computation device.\n", stderr);
  fputs("  -p       Pick execution device interactively.\n", stderr);
  fputs("  --help   Print this help and exit.\n", stderr);
#ifdef STUPIDART_NO_INTERACTIVE
  fputs("\nNote: This version of stupidart has been compiled without support for interactive use.\n", stderr);
#endif
}

int main(int argc, char** argv) {
  char *deviceopt = NULL;
  bool device_interactive = false;
  char* input_image_path;
  char* output_image_path;

#ifndef STUPIDART_NO_INTERACTIVE
  bool interactive = true;
#endif
  int n_max_iterations = 1000;
  float diff_goal = 0.05;
#ifndef STUPIDART_NO_INTERACTIVE
  bool show_text = true;
#endif

  uint32_t seed = (int32_t) lys_wall_time();

  if (argc > 1 && strcmp(argv[1], "--help") == 0) {
    print_help(argv);
    return EXIT_SUCCESS;
  }

  int c;
  while ((c = getopt(argc, argv, "hIm:g:Ts:d:p")) != -1) {
    switch (c) {
    case 'h':
      print_help(argv);
      return EXIT_SUCCESS;
      break;
#ifndef STUPIDART_NO_INTERACTIVE
    case 'I':
      interactive = false;
      break;
#endif
    case 'm':
      n_max_iterations = atoi(optarg);
      break;
    case 'g':
      assert(1 == sscanf(optarg, "%f", &diff_goal));
      break;
#ifndef STUPIDART_NO_INTERACTIVE
    case 'T':
      show_text = false;
      break;
#endif
    case 's':
      assert(1 == sscanf(optarg, "%u", &seed));
      break;
    case 'd':
      deviceopt = optarg;
      break;
    case 'p':
      device_interactive = true;
      break;
    default:
      fprintf(stderr, "error: unknown option: %c\n\n", c);
      print_help(argv);
      return EXIT_FAILURE;
    }
  }

  if (optind < argc) {
    input_image_path = argv[optind];
    if (optind + 1 < argc) {
      output_image_path = argv[optind + 1];
    } else {
      fprintf(stderr, "error: missing output image\n\n");
      print_help(argv);
      return EXIT_FAILURE;
    }
  } else {
    fprintf(stderr, "error: missing input image\n\n");
    print_help(argv);
    return EXIT_FAILURE;
  }

  int width, height;

  FILE *input_image;
  if (strcmp(input_image_path, "-") == 0) {
    input_image = fdopen(0, "r");
  } else {
    input_image = fopen(input_image_path, "r");
  }
  assert(input_image != NULL);

#ifndef STUPIDART_NO_FREEIMAGE
  FreeImage_Initialise(false);
#endif

  uint32_t* image_data = image_load(input_image_path, input_image, (unsigned int*) &width, (unsigned int*) &height);
  assert(image_data != NULL);
  assert(fclose(input_image) != EOF);
  fprintf(stderr, "Seed: %u\n", seed);
  fprintf(stderr, "Image dimensions: %dx%d\n", width, height);

  struct futhark_context_config *futcfg;
  struct futhark_context *futctx;
  char* opencl_device_name = NULL;
  lys_setup_futhark_context(argv[0],
                            deviceopt, device_interactive,
                            &futcfg, &futctx, &opencl_device_name);
  if (opencl_device_name != NULL) {
    fprintf(stderr, "Using OpenCL device: %s\n", opencl_device_name);
    fprintf(stderr, "Use -d or -p to change this.\n");
    free(opencl_device_name);
  }

  struct futhark_u32_2d *image_fut = futhark_new_u32_2d(futctx, image_data, height, width);
  free(image_data);

  uint32_t* output_image_data;
#ifndef STUPIDART_NO_INTERACTIVE
  if (!interactive) {
    output_image_data = run_noninteractive(futctx, width, height, seed,
                                           n_max_iterations, diff_goal, image_fut);
  } else {
    output_image_data = run_interactive(futctx, width, height, seed, show_text, image_fut);
  }
#else
  output_image_data = run_noninteractive(futctx, width, height, seed,
                                         n_max_iterations, diff_goal, image_fut);
#endif

  FILE *output_image;
  if (strcmp(output_image_path, "-") == 0) {
    output_image = fdopen(1, "w");
  } else {
    output_image = fopen(output_image_path, "w");
  }
  assert(output_image != NULL);
  image_save(output_image_path, output_image, output_image_data, width, height);
  assert(fclose(output_image) != EOF);

  free(output_image_data);

  futhark_context_free(futctx);
  futhark_context_config_free(futcfg);

#ifndef STUPIDART_NO_FREEIMAGE
  FreeImage_DeInitialise();
#endif

  return EXIT_SUCCESS;
}
