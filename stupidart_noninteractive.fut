import "stupidart"

entry noninteractive [h][w] (seed: i32) (n_max_iterations: i32) (diff_goal: f32)
                            (image_source: [h][w]argb.colour): ([h][w]argb.colour, i32, f32) =
  lys_core.noninteractive seed n_max_iterations diff_goal image_source
