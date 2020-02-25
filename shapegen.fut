import "base"
import "lib/github.com/diku-dk/segmented/segmented"

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

  let expand_reduce 'a 'b (sz: a -> i32) (get: a -> i32 -> b)
                          (op: b -> b -> b) (ne: b) (arr: []a) : []b =
    let szs = map sz arr
    let idxs = replicated_iota szs
    let flags = map2 (!=) idxs (rotate (i32.negate 1) idxs)
    let iotas = segmented_iota flags
    let vs = map2 (\i j -> get (unsafe arr[i]) j) idxs iotas
    in segmented_reduce op ne flags vs

  let expand_outer_reduce 'a 'b [n] (sz: a -> i32) (get: a -> i32 -> b)
                                    (op: b -> b -> b) (ne: b) (arr: [n]a) : [n]b =
    let sz' x = let s = sz x
                in if s == 0 then 1 else s
    let get' x i = if sz x == 0 then ne else get x i
    in (expand_reduce sz' get' op ne arr) :> [n]b

  -- XXX: Make this fast.  Maybe add multiple good shapes instead of the best one.
  let add [h][w] (count:i32) (image_source: [h][w]color) (image_approx: [h][w]color)
                 (rng: rng): ([h][w]color, f32, rng) =
    let image_diff = map2 (map2 color_diff) image_approx image_source

    let (rng, (score_best:f32,sq_best:o.t)) =
      let n_tries = 1000
      let rngs = rnge.split_rng n_tries rng
      let (tries, rngs) =
	let (ts, rngs) = map (o.generate count h w) rngs |> unzip
	let sz (t:o.t) : i32 = o.n_points t
	let get (t:o.t) (k:i32) : f32 =
	  match o.coordinates t k
	  case #just (y, x) ->
            let old = unsafe image_diff[y, x]
            let new = color_diff (o.color t) (unsafe image_source[y, x])
            in old - new
	  case #nothing -> 0
	let scores = expand_outer_reduce sz get (+) 0 ts
	in (zip scores ts, rngs)
      let best_try (s0, sq0) (s1, sq1) = if s0 > s1 then (s0, sq0) else (s1, sq1)
      let (score_best, sq_best) = reduce_comm best_try (-f32.inf, o.empty) tries
      let rng = rnge.join_rng rngs
      in (rng, (score_best, sq_best))

    let (image_approx', improvement) =
      if score_best > 0 then (render image_approx sq_best, score_best)
      else (image_approx, 0)

    in (image_approx', improvement, rng)
}
