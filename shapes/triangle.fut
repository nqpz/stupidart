import "../base"

let barycentric_coordinates
    ((y, x): (i32, i32))
    ((yp0, xp0) : (i32, i32))
    ((yp1, xp1) : (i32, i32))
    ((yp2, xp2) : (i32, i32)): (i32, i32, i32, i32) =
  let factor = (yp1 - yp2) * (xp0 - xp2) + (xp2 - xp1) * (yp0 - yp2)
  in if factor != 0 -- Avoid division by zero.
     then let a = ((yp1 - yp2) * (x - xp2) + (xp2 - xp1) * (y - yp2))
          let b = ((yp2 - yp0) * (x - xp2) + (xp0 - xp2) * (y - yp2))
          let c = factor - a - b
          in (factor, a, b, c)
     else (1, -1, -1, -1)

let in_range (t: i32) (a: i32) (b: i32): bool =
  (a < b && a <= t && t <= b) || (b <= a && b <= t && t <= a)

type t = {y0: i32, x0: i32,
          y1: i32, x1: i32,
          y2: i32, x2: i32,
          color: color}

let empty: t = {y0=0, x0=0, y1=0, x1=0, y2=0, x2=0, color=0}

let bounds (t: t): (i32, i32, i32, i32) =
  let y_min = i32.min (i32.min t.y0 t.y1) t.y2
  let y_max = i32.max (i32.max t.y0 t.y1) t.y2
  let x_min = i32.min (i32.min t.x0 t.x1) t.x2
  let x_max = i32.max (i32.max t.x0 t.x1) t.x2
  in (y_min, y_max, x_min, x_max)

let n_points (t: t): i32 =
  let (y_min, y_max, x_min, x_max) = bounds t
  in (y_max - y_min + 1) * (x_max - x_min + 1)

let color (t: t): color = t.color

let coordinates (t: t) (k: i32): maybe (i32, i32) =
  let (y_min, _y_max, x_min, x_max) = bounds t
  let width = (x_max - x_min + 1)
  let y = y_min + k / width
  let x = x_min + k % width
  let (factor, a, b, c) = barycentric_coordinates (y, x) (t.y0, t.x0) (t.y1, t.x1) (t.y2, t.x2)
  let in_triangle = in_range a 0 factor && in_range b 0 factor && in_range c 0 factor
  in if in_triangle then #just (y, x) else #nothing

let generate (h: i32) (w: i32) (rng: rng): (t, rng) =
  let (rng, y0) = dist_int.rand (0, h - 1) rng
  let (rng, x0) = dist_int.rand (0, w - 1) rng
  let (rng, y1) = dist_int.rand (0, h - 1) rng
  let (rng, x1) = dist_int.rand (0, w - 1) rng
  let (rng, y2) = dist_int.rand (0, h - 1) rng
  let (rng, x2) = dist_int.rand (0, w - 1) rng
  let (rng, color) = rand_color rng
  in ({y0, x0, y1, x1, y2, x2, color}, rng)
