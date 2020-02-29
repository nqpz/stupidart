import "../lib/github.com/diku-dk/cpprandom/random"
import "../lib/github.com/athas/matte/colour"
import "cielab"

module rnge = minstd_rand
module dist = uniform_real_distribution f32 rnge
module dist_int = uniform_int_distribution i32 rnge
type rng = rnge.rng

type maybe 'a = #just a | #nothing

let rand_color (rng: rng): (rng, color) =
  let (rng, li) = dist_int.rand (0, li_max) rng
  let (rng, ai) = dist_int.rand (0, ai_max) rng
  let (rng, bi) = dist_int.rand (0, bi_max) rng
  in (rng, cielab_pack_ints (u32.i32 li, u32.i32 ai, u32.i32 bi))

let color_diff: color -> color -> f32 = cielab_delta_packed

let color_diff_max (c: color): f32 =
  f32.max (color_diff (cielab_pack_ints (0, 0, 0)) c)
          (color_diff (cielab_pack_ints
                       (u32.i32 li_max, u32.i32 ai_max, u32.i32 bi_max)) c)
