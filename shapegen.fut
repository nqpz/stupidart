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

  let index2 (off_y:i32,off_x:i32) (w: i32) (t: t) (k: i32): i32 =
    match o.coordinates t k
    case #just (y, x) -> w * (off_y+y) + off_x + x
    case #nothing -> -1

  let render2 [a][h][w] (image: [h][w]color) (hG:i32,wG:i32) (arg:[a](i32,i32,f32,t)) : ([h][w]color,f32) =
    let pixels = copy (flatten image)
    let sz (_,_,score,t:t) : i32 = if score > 0 then o.n_points t else 0
    let get (j,i,_,t:t) (k:i32) =
      (index2 (j*hG,i*wG) w t k,
       o.color t)
    let (indices,colors) = unzip <| expand sz get arg
    let pixels' = scatter pixels indices colors
    let score = reduce (+) 0 (map (\(_,_,s,_) -> f32.max 0 s) arg)
    in (unflatten h w pixels',score)

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

  let gridify 'b (G:i32) (rng:rng) (f:(i32,i32)->rng->(rng,b)) : (rng,[][]b) =
    let (rngs, res) = unsafe
      unzip <| map2 (\yG rng ->
		       let (rngs, res) =
			 unzip <| map2 (\xG rng -> f (yG,xG) rng)
	                               (iota G) (rnge.split_rng G rng)
		       in (rnge.join_rng rngs, res)
	            ) (iota G) (rnge.split_rng G rng)
    in (rnge.join_rng rngs, res)

  -- XXX: Make this fast.  Maybe add multiple good shapes instead of the best one.
  let add [h][w] (n_objs:i32) (image_source: [h][w]color) (image_approx: [h][w]color)
                 (rng: rng): ([h][w]color, f32, rng) =
    let image_diff = map2 (map2 color_diff) image_approx image_source

    let on_grid (hG:i32,wG:i32) (j:i32,i:i32) (rng:rng) : (rng, (i32,i32,f32,o.t)) =
      let n_tries = 1000
      let rngs = rnge.split_rng n_tries rng
      let (tries, rngs) =
	let (ts, rngs) = map (o.generate n_objs hG wG) rngs |> unzip
	let sz (t:o.t) : i32 = o.n_points t
	let get (t:o.t) (k:i32) : f32 =
	  match o.coordinates t k
	  case #just (y, x) ->
            let old = unsafe image_diff[j*hG+y, i*wG+x]
            let new = color_diff (o.color t) (unsafe image_source[j*hG+y, i*wG+x])
            in old - new
	  case #nothing -> 0
	let scores = expand_outer_reduce sz get (+) 0 ts
	in (zip scores ts, rngs)

      let best_try (s0, sq0) (s1, sq1) = if s0 > s1 then (s0, sq0) else (s1, sq1)
      let (score_best, sq_best) = reduce_comm best_try (-f32.inf, o.empty) tries
      let rng = rnge.join_rng rngs
      in (rng, (j,i,score_best, sq_best))

    --let G = 1
    --let (hG,wG) = (h / G, w / G)
    --let (rng, res:[][](i32,i32,f32,o.t)) = gridify G rng (on_grid (hG,wG))
    --let (image_approx', improvement) = render2 image_approx (hG,wG) (flatten res)

    let (rng, (_,_,score_best,sq_best)) = on_grid (h,w) (0,0) rng
    let (image_approx', improvement) =
      if score_best > 0 then (render image_approx sq_best, score_best)
      else (image_approx, 0)

    in (image_approx', improvement, rng)
}
