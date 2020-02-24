import "base"

module type shape = {
  type t

  val empty: t

  val n_points: t -> i32

  val color: t -> color

  val coordinates: t -> i32 -> maybe (i32, i32)

  val generate: i32 -> i32 -> rng -> (t, rng)
}

module mk_full_shape (o: shape) = {
  type t = o.t

  let index (w: i32) (t: t) (k: i32): i32 =
    match o.coordinates t k
    case #just (y, x) -> w * y + x
    case #nothing -> -1

  let render [h][w] (image: [h][w]color) (t: t): [h][w]color =
    let pixels = copy (flatten image)
    let n = o.n_points t
    let indices = map (index w t) (0..<n)
    let pixels' = scatter pixels indices (replicate n (o.color t))
    in unflatten h w pixels'

  -- XXX: Make this fast.  Maybe add multiple good shapes instead of the best one.
  let add [h][w] (image_source: [h][w]color) (image_approx: [h][w]color)
                 (rng: rng): ([h][w]color, f32, rng) =
    let image_diff = map2 (map2 color_diff) image_approx image_source
    let n_tries = 1000
    let rngs = rnge.split_rng n_tries rng

    let try (rng: rng): ((f32, t), rng) =
      let (t, rng) = o.generate h w rng
      let score = loop score = 0 for k < o.n_points t do
                  match o.coordinates t k
                  case #just (y, x) ->
                    let old = unsafe image_diff[y, x]
                    let new = color_diff (o.color t) (unsafe image_source[y, x])
                    in score + old - new
                  case #nothing ->
                    score
    in ((score, t), rng)

  let (tries, rngs) = unzip (map try rngs)

  let best_try (s0, sq0) (s1, sq1) = if s0 > s1 then (s0, sq0) else (s1, sq1)
  let (score_best, sq_best) = reduce_comm best_try (-f32.inf, o.empty) tries
  let (image_approx', improvement) =
    if score_best > 0
    then (render image_approx sq_best, score_best)
    else (image_approx, 0)

  let rng = rnge.join_rng rngs
  in (image_approx', improvement, rng)
}
