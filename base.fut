import "lib/github.com/diku-dk/cpprandom/random"
import "lib/github.com/athas/matte/colour"

module rnge = minstd_rand
module dist_int = uniform_int_distribution i32 rnge
type rng = rnge.rng

type maybe 'a = #just a | #nothing

let color_diff (c0: argb.colour) (c1: argb.colour): i32 =
  i32.abs (c0 - c1)
