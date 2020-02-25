import "lib/github.com/diku-dk/cpprandom/random"
import "lib/github.com/athas/matte/colour"
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
