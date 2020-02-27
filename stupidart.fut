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

  type shape = #random | #triangle | #circle | #rectangle
  type sized_state [h][w] = {startseed:i32, paused: bool, diff_max: f32,
                             diff: f32, count: i32,
                             shape: shape,
                             image_source: [h][w]color,
                             image_approx: [h][w]color,
                             resetwhen: f32} -- <=0: no resetting,
                                             --  >0: auto reset when diff < s.reset
  type~ state = sized_state [][]

  let state_from_image_source [h][w] (seed: i32) (shape:shape) (image_source: [h][w]color) : state =
    let diff_max = reduce_comm (+) 0 (flatten (map (map color_diff_max) image_source))
    let black = cielab_pack (srgb_to_cielab (0, 0, 0))
    let image_approx = replicate h (replicate w black)
    let diff = reduce_comm (+) 0 (flatten (map2 (map2 (color_diff)) image_approx image_source))
    in {startseed=seed, paused=false, diff_max, diff, shape,
        image_source, image_approx, count=0, resetwhen=0}

  entry init [h][w] (seed: i32) (image_source: [h][w]argb.colour) : state =
    let image_source' = map (map (\c -> let (r, g, b, _a) = argb.to_rgba c
                                        in cielab_pack (srgb_to_cielab (r, g, b))))
                            image_source
    in state_from_image_source seed #random image_source'

  let reset (s:state) : state =
    state_from_image_source s.startseed s.shape s.image_source

  entry diff_percent (s: state): f32 = 100 * s.diff / s.diff_max

  entry text (s: state) : string [] =
    "Object type (1-4), Reset (r), \nHide text (F1), Quit (esc)\nAuto reset: " ++
    (if s.resetwhen > 0 then "on" else "off")

  let keydown (key: i32) (s: state) =
    if key == SDLK_SPACE then s with paused = !s.paused
    else if key == SDLK_1 then s with shape = #random
    else if key == SDLK_2 then s with shape = #triangle
    else if key == SDLK_3 then s with shape = #circle
    else if key == SDLK_4 then s with shape = #rectangle
    else if key == SDLK_r then (if s.resetwhen <= 0 then
                                let d = diff_percent s
                                in reset s with resetwhen = d
                                else reset s)
    else s

  let event (e: event) (s: state): state =
    match e
    case #step _td ->
      if s.paused then s
      else let d = s.resetwhen
           in if diff_percent s < d then reset s with resetwhen = d
              else let image_approx = same_dims_2d s.image_source s.image_approx
                   let rng = rnge.rng_from_seed [s.count+s.startseed]
                   let (shape:shape,rng) =
                     if s.shape == #random then
                     let (rng, choice) = dist_int.rand (0, 2) rng
                     in ((if choice == 0 then #triangle
                          else if choice == 1 then #circle
                          else #rectangle),rng)
                     else (s.shape,rng)
                   let (image_approx', improved) =
                     match shape
                     case #triangle -> triangle.add s.count s.image_source image_approx rng
                     case #circle -> circle.add s.count s.image_source image_approx rng
                     case _rectangle_or_random -> rectangle.add s.count s.image_source image_approx rng
                   in s with image_approx = image_approx'
                with diff = s.diff - improved
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
