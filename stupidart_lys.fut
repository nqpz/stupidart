import "lib/github.com/diku-dk/lys/lys_core_entries"
module core = import "stupidart"

entry init [h][w] (seed: i32) (image_source: [h][w]argb.colour): core.state =
  core.init seed image_source

entry text_content (s: core.state): (f32, bool) =
  core.text_content s

entry noninteractive [h][w] (seed: i32) (n_max_iterations: i32) (diff_goal: f32)
                            (image_source: [h][w]argb.colour): ([h][w]argb.colour, i32, f32) =
  core.noninteractive seed n_max_iterations diff_goal image_source

open lys_core_entries core
