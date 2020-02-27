#include "lib/github.com/diku-dk/lys/liblys.h"

#define _XOPEN_SOURCE
#include <unistd.h>
#include <getopt.h>
#include "pam.h"

#define MAX_FPS 60
#define FONT_SIZE 20

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

void print_help(char** argv) {
  printf("Usage: %s options... input.pam output.pam\n", argv[0]);
  puts("");
  puts("Read an image in Netpbm PAM format, iterate on it, and and save it\nafter closing the window.");
  puts("");
  puts("Options:");
  puts("  -d DEV  Set the computation device.");
  puts("  -i      Select execution device interactively.");
  puts("  --help  Print this help and exit.");
}

int main(int argc, char** argv) {
  char *deviceopt = NULL;
  bool device_interactive = false;
  char* input_image_path;
  char* output_image_path;

  if (argc > 1 && strcmp(argv[1], "--help") == 0) {
    print_help(argv);
    return EXIT_SUCCESS;
  }

  int c;
  while ((c = getopt(argc, argv, "d:i")) != -1) {
    switch (c) {
    case 'd':
      deviceopt = optarg;
      break;
    case 'i':
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

  int32_t seed = (int32_t) lys_wall_time();

  int width, height;

  FILE *input_image;
  if (strcmp(input_image_path, "-") == 0) {
    input_image = fdopen(0, "r");
  } else {
    input_image = fopen(input_image_path, "r");
  }
  assert(input_image != NULL);
  int32_t* image_data = pam_load(input_image, (unsigned int*) &width, (unsigned int*) &height);
  assert(image_data != NULL);
  assert(fclose(input_image) != EOF);
  fprintf(stderr, "Seed: %d\n", seed);
  fprintf(stderr, "Image dimensions: %dx%d\n", width, height);

  struct lys_context ctx;
  lys_setup(&ctx, width, height, MAX_FPS, deviceopt, device_interactive, 0);

  ctx.event_handler_data = NULL;
  ctx.event_handler = handle_event;

  struct futhark_i32_2d *image_fut = futhark_new_i32_2d(ctx.fut, image_data, height, width);
  free(image_data);

  futhark_entry_init(ctx.fut, &ctx.state, seed, image_fut);

  futhark_free_i32_2d(ctx.fut, image_fut);

  SDL_ASSERT(TTF_Init() == 0);

  struct internal internal;
  ctx.event_handler_data = (void*) &internal;
  internal.show_text = true;
  internal.font = TTF_OpenFont("NeomatrixCode.ttf", FONT_SIZE);
  SDL_ASSERT(internal.font != NULL);

  lys_run_sdl(&ctx);

  TTF_CloseFont(internal.font);

  FILE *output_image;
  if (strcmp(output_image_path, "-") == 0) {
    output_image = fdopen(1, "w");
  } else {
    output_image = fopen(output_image_path, "w");
  }
  assert(output_image != NULL);
  pam_save(output_image, ctx.data, ctx.width, ctx.height);
  assert(fclose(output_image) != EOF);
  free(ctx.data);

  futhark_context_free(ctx.fut);
  futhark_context_config_free(ctx.futcfg);

  return EXIT_SUCCESS;
}
