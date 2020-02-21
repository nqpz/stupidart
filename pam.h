/* Netpbm PAM graphics format loading and saving without alpha channel. */

int32_t* pam_load(FILE *f, unsigned int *width, unsigned int *height) {
  assert(0 == fscanf(f, "P7\n"));
  int c = fgetc(f);
  if (c == '#') {
    while (fgetc(f) != '\n');
  } else {
    ungetc(c, f);
  }
  assert(1 == fscanf(f, "WIDTH %u\n", width));
  assert(1 == fscanf(f, "HEIGHT %u\n", height));
  unsigned int depth;
  assert(1 == fscanf(f, "DEPTH %u\n", &depth));
  assert(3 == depth);
  assert(0 == fscanf(f, "MAXVAL 255\n"));
  assert(0 == fscanf(f, "TUPLTYPE RGB\n"));
  assert(0 == fscanf(f, "ENDHDR\n"));
  int32_t* image = (int32_t*) malloc(*width * *height * sizeof(int32_t));
  if (image == NULL) {
    return NULL;
  }
  for (unsigned int i = 0; i < *width * *height; i++) {
    int r, g, b;
    b = fgetc(f);
    g = fgetc(f);
    r = fgetc(f);

    image[i] = (0xff << 24) | (b << 16) | (g << 8) | r;
  }
  return image;
}

void pam_save(FILE* f, const int32_t* image,
              unsigned int width, unsigned int height) {
  fprintf(f, "P7\n");
  fprintf(f, "WIDTH %u\n", width);
  fprintf(f, "HEIGHT %u\n", height);
  fprintf(f, "DEPTH 3\n");
  fprintf(f, "MAXVAL 255\n");
  fprintf(f, "TUPLTYPE RGB\n");
  fprintf(f, "ENDHDR\n");
  for (unsigned int i = 0; i < width * height; i++) {
    int r, g, b;
    r = image[i] & 0x0000ff;
    g = (image[i] & 0x00ff00) >> 8;
    b = (image[i] & 0xff0000) >> 16;
    fputc(b, f);
    fputc(g, f);
    fputc(r, f);
  }
}
