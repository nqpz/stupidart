import "lib/github.com/diku-dk/lys/lys"
import "lib/github.com/diku-dk/lys/lys_core_entries"

import "base"
import "shapegen"

module rectangle = mk_full_shape (import "shapes/rectangle")
module circle = mk_full_shape (import "shapes/circle")
module triangle = mk_full_shape (import "shapes/triangle")

let same_dims_2d 'a [m][n][m1][n1] (_source: [m][n]a) (target: [m1][n1]a): [m][n]a =
  target :> [m][n]a


module lys_core = {
  type sized_state [h][w] = {rng: rng, paused: bool, diff_max: f32, diff: f32, count: i32,
                             shape: #random | #triangle | #circle | #rectangle,
                             image_source: [h][w]color,
                             image_approx: [h][w]color}
  type~ state = sized_state [][]

  entry init [h][w] (seed: i32) (image_source: [h][w]argb.colour): state =
    let rng = rnge.rng_from_seed [seed]
    let image_source' = map (map (\c -> let (r, g, b, _a) = argb.to_rgba c
                                        in cielab_pack (srgb_to_cielab (r, g, b))))
                            image_source
    let diff_max = reduce_comm (+) 0 (flatten (map (map color_diff_max) image_source'))
    let black = cielab_pack (srgb_to_cielab (0, 0, 0))
    let image_approx = replicate h (replicate w black)
    let diff = reduce_comm (+) 0 (flatten (map2 (map2 (color_diff)) image_approx image_source'))
    in {rng, paused=false, diff_max, diff, shape=#random, image_source=image_source', image_approx, count=0}

  entry diff_percent (s: state): f32 = 100 * s.diff / s.diff_max

  let keydown (key: i32) (s: state) =
    if key == SDLK_SPACE then s with paused = !s.paused
    else if key == SDLK_1 then s with shape = #random
    else if key == SDLK_2 then s with shape = #triangle
    else if key == SDLK_3 then s with shape = #circle
    else if key == SDLK_4 then s with shape = #rectangle
    else s

  let event (e: event) (s: state): state =
    match e
    case #step _td ->
      if s.paused then s
      else let image_approx = same_dims_2d s.image_source s.image_approx
           let (shape : #circle | #triangle | #rectangle, rng) =
             match s.shape
             case #random ->
               let (rng, choice) = dist_int.rand (0, 2) s.rng
               in (if choice == 0 then #triangle
                   else if choice == 1 then #circle
                   else #rectangle,
                   rng)
             case #triangle -> (#triangle, s.rng)
             case #circle -> (#circle, s.rng)
             case #rectangle -> (#rectangle, s.rng)
           let (image_approx', improved, rng') =
             match shape
             case #triangle ->   triangle.add s.count s.image_source image_approx rng
             case #circle ->       circle.add s.count s.image_source image_approx rng
             case #rectangle -> rectangle.add s.count s.image_source image_approx rng
           in s with image_approx = image_approx'
                with diff = s.diff - improved
                with rng = rng'
	        with count = s.count + 1
    case #keydown {key} -> keydown key s
    case _ -> s

  let render (s: state): [][]argb.colour =
    map (map (\c -> let (r, g, b) = cielab_to_srgb (cielab_unpack c)
                    in argb.from_rgba r g b 1)) s.image_approx

  let resize _ _ (s: state): state = s
}

open lys_core
open lys_core_entries lys_core
