import "../base"

type t = {y_top: i32, height: i32,
          x_left: i32, width: i32,
          color: color}

let empty: t = {y_top=0, height=0, x_left=0, width=0, color=0}

let n_points (t: t): i32 = t.height * t.width

let color (t: t): color = t.color

let coordinates (t: t) (k: i32): maybe (i32, i32) =
  let y = t.y_top + k / t.width
  let x = t.x_left + k % t.width
  in #just (y, x)

let generate (count: i32) (h: i32) (w: i32) (rng: rng): (t, rng) =
  let (rng, y_top) = dist_int.rand (0, h - 1) rng
  let max_h = h - y_top
  let max_h' = i32.max (i32.min max_h 50) (max_h - count / 100)
  let (rng, height) = dist_int.rand (1, max_h') rng
  let (rng, x_left) = dist_int.rand (0, w - 1) rng
  let max_w = w - x_left
  let max_w' = i32.max (i32.min max_w 50) (max_w - count / 100)
  let (rng, width) = dist_int.rand (1, max_w') rng
  let (rng, color) = rand_color rng
  in ({y_top, height, x_left, width, color}, rng)
