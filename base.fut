import "lib/github.com/diku-dk/cpprandom/random"
import "lib/github.com/athas/matte/colour"
import "cielab"

module rnge = minstd_rand
module dist = uniform_real_distribution f32 rnge
module dist_int = uniform_int_distribution i32 rnge
type rng = rnge.rng

type maybe 'a = #just a | #nothing

let rand_color (rng: rng): (rng, color) =
  let (rng, l) = dist.rand (cielab_bounds.l.min, cielab_bounds.l.max) rng
  let (rng, a) = dist.rand (cielab_bounds.a.min, cielab_bounds.a.max) rng
  let (rng, b) = dist.rand (cielab_bounds.b.min, cielab_bounds.b.max) rng
  in (rng, cielab_pack (l, a, b))

let color_diff (c1: color) (c2: color): f32 =
  cielab_delta (cielab_unpack c1) (cielab_unpack c2)
