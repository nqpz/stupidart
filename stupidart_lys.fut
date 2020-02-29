import "lib/github.com/diku-dk/lys/lys_core_entries"
import "stupidart"

entry init [h][w] (seed: i32) (image_source: [h][w]argb.colour): lys_core.state =
  lys_core.init seed image_source

entry text_content (s: lys_core.state): (f32, bool) =
  lys_core.text_content s

entry noninteractive [h][w] (seed: i32) (n_max_iterations: i32) (diff_goal: f32)
                            (image_source: [h][w]argb.colour): ([h][w]argb.colour, i32, f32) =
  lys_core.noninteractive seed n_max_iterations diff_goal image_source

open lys_core_entries lys_core
