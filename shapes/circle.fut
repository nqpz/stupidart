import "../base"

type t = {y_center: i32, x_center: i32,
          radius: i32, color: color}

let empty: t = {y_center=0, x_center=0, radius=0, color=0}

let n_points (t: t): i32 = (t.radius * 2)**2

let color (t: t): color = t.color

let coordinates (t: t) (k: i32): maybe (i32, i32) =
  let y = t.y_center - t.radius + k / (t.radius * 2)
  let x = t.x_center - t.radius + k % (t.radius * 2)
  let in_circle = f32.sqrt (r32 (y - t.y_center)**2 + r32 (x - t.x_center)**2) < r32 t.radius
  in if in_circle then #just (y, x) else #nothing

let generate (n_objs: i32) (h: i32) (w: i32) (rng: rng): (t, rng) =
  let (rng, y_center) = dist_int.rand (0, h - 1) rng
  let (rng, x_center) = dist_int.rand (0, w - 1) rng
  let radius_max = i32.min (i32.min x_center (w - x_center))
                           (i32.min y_center (h - y_center))
  let rad_max = i32.max (i32.min radius_max 50) (radius_max - n_objs / 100)
  let (rng, radius) = dist_int.rand (1, rad_max) rng
  let (rng, color) = rand_color rng
  in ({y_center, x_center, radius, color}, rng)
