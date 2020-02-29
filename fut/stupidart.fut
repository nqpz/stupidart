import "../lib/github.com/diku-dk/lys/lys"
import "base"
import "shapegen"

module rectangle = mk_full_shape (import "shapes/rectangle")
module circle = mk_full_shape (import "shapes/circle")
module triangle = mk_full_shape (import "shapes/triangle")

let same_dims_2d 'a 'b [m][n][m1][n1] (_source: [m][n]a) (target: [m1][n1]b): [m][n]b =
  target :> [m][n]b

type shape = #random | #triangle | #circle | #rectangle
type sized_state [h][w] = {startseed:i32, paused: bool, diff_max: f32,
                           diff: f32, count: i32,
                           shape: shape,
                           image_source: [h][w]color,
                           image_approx: [h][w]color,
                           image_diff: [h][w]f32,
                           resetwhen: f32} -- <=0: no resetting,
                                           --  >0: auto reset when diff < s.reset
type~ state = sized_state [][]

let state_from_image_source [h][w] (seed: i32) (shape:shape) (image_source: [h][w]color): state =
  let diff_max = reduce_comm (+) 0 <| flatten (map (map color_diff_max) image_source)
  let black = cielab_pack <| srgb_to_cielab (0, 0, 0)
  let image_approx = replicate h <| replicate w black
  let image_diff = map2 (map2 color_diff) image_approx image_source
  let diff = reduce_comm (+) 0 <| flatten image_diff
  in {startseed=seed, paused=false, diff_max, diff, shape,
      image_source, image_approx, image_diff, count=0, resetwhen=0}

let init [h][w] (seed: i32) (image_source: [h][w]argb.colour): state =
  let image_source' = map (map (\c -> let (r, g, b, _a) = argb.to_rgba c
                                      in cielab_pack <| srgb_to_cielab (r, g, b)))
                          image_source
  in state_from_image_source seed #random image_source'

let reset (s: state): state =
  state_from_image_source s.startseed s.shape s.image_source

let diff_ratio (diff: f32) (s: state): f32 =
  diff / s.diff_max

let text_content (s: state): (f32, bool) =
  (100 * diff_ratio s.diff s, s.resetwhen > 0)

let keydown (key: i32) (s: state) =
  if key == SDLK_SPACE then s with paused = !s.paused
  else if key == SDLK_1 then s with shape = #random
  else if key == SDLK_2 then s with shape = #triangle
  else if key == SDLK_3 then s with shape = #circle
  else if key == SDLK_4 then s with shape = #rectangle
  else if key == SDLK_r then (if s.resetwhen <= 0
                              then let d = diff_ratio s.diff s
                                   in reset s with resetwhen = d
                              else reset s)
  else s

let step_step [h][w] ((s, image_approx, image_diff, diff, count):
                       (state, *[h][w]color, *[h][w]f32, f32, i32)):
                       (state, *[h][w]color, *[h][w]f32, f32, i32) =
  if diff_ratio diff s < s.resetwhen
  then (reset s with resetwhen = s.resetwhen, image_approx, image_diff, diff, count)
  else let rng = rnge.rng_from_seed [count + s.startseed]
       let (shape:shape, rng) =
         if s.shape == #random
         then let (rng, choice) = dist_int.rand (0, 2) rng
              in ((if choice == 0 then #triangle
                   else if choice == 1 then #circle
                   else #rectangle), rng)
         else (s.shape, rng)
       let (image_approx', image_diff', improved) =
         match shape
         case #triangle -> triangle.add count s.image_source image_approx image_diff rng
         case #circle -> circle.add count s.image_source image_approx image_diff rng
         case _rectangle_or_random -> rectangle.add count s.image_source image_approx image_diff rng
       in (s, image_approx', image_diff', diff - improved, count + 1)

let step (n_max_iterations: i32) (diff_goal: f32) (s: state): (state, i32) =
  let image_approx = copy (same_dims_2d s.image_source s.image_approx)
  let image_diff = copy (same_dims_2d s.image_source s.image_diff)
  let ((s', image_approx', image_diff', diff', count'), n_iterations) =
    loop ((s, image_approx, image_diff, diff, count), step_i) =
      ((s, image_approx, image_diff, s.diff, s.count), 0)
    while diff_ratio diff s > diff_goal && step_i < n_max_iterations
    do (step_step (s, image_approx, image_diff, diff, count), step_i + 1)
  in (s' with image_approx = image_approx'
         with image_diff = image_diff'
         with diff = diff'
         with count = count',
      n_iterations)

let event (e: event) (s: state): state =
  match e
  case #step _td -> if s.paused then s else (step 1 0 s).0
  case #keydown {key} -> keydown key s
  case _ -> s

let render (s: state): [][]argb.colour =
  map (map (\c -> let (r, g, b) = cielab_to_srgb (cielab_unpack c)
                  in argb.from_rgba r g b 1)) s.image_approx

let resize _ _ (s: state): state = s

let noninteractive [h][w] (seed: i32) (n_max_iterations: i32) (diff_goal: f32)
                          (image_source: [h][w]argb.colour):
                          ([h][w]argb.colour, i32, f32) =
  let s = init seed image_source
  let (s', n_iterations) = step n_max_iterations diff_goal s
  in (render s', n_iterations, 100 * diff_ratio s'.diff s')
