import "../lib/github.com/diku-dk/segmented/segmented"
import "base"

module type shape = {
  type t

  val empty: t

  val n_points: t -> i32

  val color: t -> color

  val coordinates: t -> i32 -> maybe (i32, i32)

  val generate: i32 -> i32 -> i32 -> rng -> (t, rng)
}

module mk_full_shape (o: shape) = {
  type t = o.t

  -- A few general utilities
  let indices [n] 'a (_: [n]a): [n]i32 = map i32.i64 (0..<n)
  let indexed [n] 'a (xs: [n]a): [n](i32, a) = zip (map i32.i64 (0..<n)) xs

  -- Rendering utilities
  let index_and_diff [n] (c: color) (image_source_flat: [n]color)
                         (off_y: i32, off_x: i32) (w: i32) (t: t) (k: i32): (i32, f32) =
    match o.coordinates t k
    case #just (y, x) ->
      let idx = w * (off_y + y) + off_x + x
      in (idx, color_diff c image_source_flat[idx])
    case #nothing -> (-1, 0)

  let render [a][h][w] (image_source: [h][w]color) (image_approx: *[h][w]color)
                       (image_diff: *[h][w]f32) (hG: i32, wG: i32) (arg: [a]((i32, i32, t), f32)):
                       (*[h][w]color, *[h][w]f32, f32) =
    let image_source_flat = flatten image_source
    let sz ((_, _, t:t), score): i64 = if score > 0 then i64.i32 (o.n_points t) else 0
    let get ((j, i, t:t), _) (k: i64) =
      let c = o.color t
      let (idx, diff) = index_and_diff c image_source_flat (j * hG, i * wG) (i32.i64 w) t (i32.i64 k)
      in (i64.i32 idx, c, diff)
    let (indices,colors,diffs) = unzip3 (expand sz get arg)
    let image_approx' = unflatten (scatter (flatten image_approx) indices colors)
    let image_diff' = unflatten (scatter (flatten image_diff) indices diffs)
    let score = f32.sum (map (\(_, s) -> f32.max 0 s) arg)
    in (image_approx', image_diff', score)

  -- Parallelisation using gridification
  let gridify 'b (G: i64) (rng: rng) (f:(i32, i32) -> rng -> b): [G][G]b =
    map (\(yG, rng) ->
           map (\(xG, rng) -> f (yG, xG) rng)
               (indexed (rnge.split_rng G rng))
        ) <| indexed (rnge.split_rng G rng)

  -- Parallelising art generation
  --
  -- 0. Decide on a G x G grid partitioning (G small prime)
  -- 1. For each (j,i) grid pair, generate 1000 (n_tries) object
  --    specifications, paired with the grid pairs.
  -- 2. Flatten these specifications; straightforward using gridify
  --    above.
  -- 3. Use expand_outer_reduce to generate pixel score
  --    points for each object using sz and get. The provided reduce
  --    function adds the scores with 0 as the neutral element.
  -- 4. Reshape to the [G][G][1000](score,o.t)
  -- 5. Now do a map (map (reduce ...)) to find the candidate for
  --    each grid cell.
  -- 6. Write the objects to the image using render.
  let Gs: []i32 = [1, 2, 3, 5, 7, 11]

  let add [h][w] (count: i32) (image_source: [h][w]color) (image_approx: *[h][w]color)
                 (image_diff: *[h][w]f32) (rng: rng): (*[h][w]color, *[h][w]f32, f32) =
    let (rng, Gi) = dist_int.rand (0, i32.i64 (length Gs - 1)) rng
    let G' = Gs[Gi]
    let G = i64.i32 G'
    let n_tries = 500
    let (hG, wG) = (i32.i64 h / G', i32.i64 w / G')
    let tries = gridify G rng (\(j, i) rng ->
                                 let rngs = rnge.split_rng n_tries rng
                                 let (ts, _) = unzip <| map (o.generate count hG wG) rngs
                                 in map (\t -> (j, i, t)) ts)

    let flat_tries = flatten_3d tries
    let sz (_, _, t: o.t): i64 = i64.i32 (o.n_points t)
    let get (j, i, t: o.t) (k: i64): f32 =
      (match o.coordinates t (i32.i64 k)
       case #just (y, x) ->
         let old = image_diff[j * hG + y, i * wG + x]
         let new = color_diff (o.color t) image_source[j * hG + y, i * wG + x]
         in old - new
       case #nothing -> 0)
    let flat_tries_with_scores =
      zip flat_tries <| expand_outer_reduce sz get (+) 0 flat_tries
    let tries_with_scores: [G][G][n_tries]((i32, i32, o.t), f32) =
      unflatten_3d flat_tries_with_scores
    let best_try (tr0, s0) (tr1, s1) = if s0 > s1 then (tr0, s0) else (tr1, s1)
    let best_tries: [G * G]((i32, i32, o.t), f32) =
      flatten <| map (map (reduce_comm best_try ((-1, -1, o.empty), -f32.inf))) tries_with_scores
    in render image_source image_approx (copy image_diff) (hG, wG) best_tries
}
