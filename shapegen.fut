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

  -- A few general utilities
  let indices [n] 'a (_:[n]a) : [n]i32 = iota n
  let indexed [n] 'a (xs:[n]a) : [n](i32,a) = zip (iota n) xs

  -- A few flattening utility functions that are still not
  -- available in the segmented library
  let expand_reduce 'a 'b (sz: a -> i32) (get: a -> i32 -> b)
                          (op: b -> b -> b) (ne: b) (arr: []a) : []b =
    let szs = map sz arr
    let idxs = replicated_iota szs
    let flags = map2 (!=) idxs (rotate (i32.negate 1) idxs)
    let iotas = segmented_iota flags
    let vs = map2 (\i j -> get (arr[i]) j) idxs iotas
    in segmented_reduce op ne flags vs

  let expand_outer_reduce 'a 'b [n] (sz: a -> i32) (get: a -> i32 -> b)
                                    (op: b -> b -> b) (ne: b) (arr: [n]a) : [n]b =
    let sz' x = let s = sz x
                in if s == 0 then 1 else s
    let get' x i = if sz x == 0 then ne else get x i
    in (expand_reduce sz' get' op ne arr) :> [n]b

  -- Rendering utilities
  let index (off_y:i32,off_x:i32) (w: i32) (t: t) (k: i32): i32 =
    match o.coordinates t k
    case #just (y, x) -> w * (off_y+y) + off_x + x
    case #nothing -> -1

  let render [a][h][w] (image: [h][w]color) (hG:i32,wG:i32) (arg:[a]((i32,i32,t),f32)) : ([h][w]color,f32) =
    let pixels = copy (flatten image)
    let sz ((_,_,t:t),score) : i32 = if score > 0 then o.n_points t else 0
    let get ((j,i,t:t),_) (k:i32) =
      (index (j*hG,i*wG) w t k,
       o.color t)
    let (indices,colors) = unzip <| expand sz get arg
    let pixels' = scatter pixels indices colors
    let score = reduce (+) 0 (map (\(_,s) -> f32.max 0 s) arg)
    in (unflatten h w pixels',score)

  -- Parallelisation using gridification
  let gridify 'b (G:i32) (rng:rng) (f:(i32,i32)->rng->b) : []b =
    flatten <| map (\(yG,rng) ->
                      map (\(xG,rng) -> f (yG,xG) rng)
                          (indexed(rnge.split_rng G rng))
                   ) (indexed(rnge.split_rng G rng))

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

  let Gs = [1i32,2,3,5,7,11]

  let add [h][w] (count:i32) (image_source: [h][w]color) (image_approx: [h][w]color)
                 (rng: rng): ([h][w]color, f32) =
    let image_diff = map2 (map2 color_diff) image_approx image_source

    let (rng, Gi) = dist_int.rand (0,length Gs - 1) rng
    let G = Gs[Gi]
    let n_tries = 500
    let (hG,wG) = (h / G, w / G)
    let grid_cells = G*G
    let tries: [grid_cells][n_tries](i32,i32,o.t) =
      gridify G rng (\(j,i) rng ->
                       let rngs = rnge.split_rng n_tries rng
                       let (ts, _) = unzip <| map (o.generate count hG wG) rngs
                       in map (\t -> (j,i,t)) ts)
              :> [grid_cells][n_tries](i32,i32,o.t)

    let flat_tries = flatten tries
    let sz (_,_,t:o.t) : i32 = o.n_points t
    let get (j,i,t:o.t) (k:i32) : f32 =
      (match o.coordinates t k
       case #just (y, x) ->
         let old = image_diff[j*hG+y, i*wG+x]
         let new = color_diff (o.color t) (image_source[j*hG+y, i*wG+x])
         in old - new
       case #nothing -> 0)
    let flat_tries_with_scores =
      zip flat_tries (expand_outer_reduce sz get (+) 0 flat_tries)
    let tries_with_scores : [G][G][n_tries]((i32,i32,o.t),f32) =
      map (unflatten G n_tries) (unflatten G (G*n_tries) flat_tries_with_scores)
    let best_try (tr0, s0) (tr1, s1) = if s0 > s1 then (tr0, s0) else (tr1, s1)
    let best_tries : [grid_cells]((i32,i32,o.t),f32) =
      (flatten <|
       map (map (reduce_comm best_try ((-1,-1,o.empty),-f32.inf))) tries_with_scores)
      :> [grid_cells]((i32,i32,o.t),f32)

    let (image_approx', improvement) = render image_approx (hG,wG) best_tries

    in (image_approx', improvement)
}
