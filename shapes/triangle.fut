import "../base"

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

type pnt = (i32,i32)
type triangle = (pnt,pnt,pnt)

let triarea2 ((x1,y1):pnt) ((x2,y2):pnt) ((x3,y3):pnt) : i32 =   -- twice the area of a triangle
  i32.abs(x1*(y2-y3)+x2*(y3-y1)+x3*(y1-y2))

let point_in_triangle ((p1,p2,p3):triangle) (p:pnt) : bool =
  let sum = triarea2 p1 p2 p + triarea2 p1 p3 p + triarea2 p2 p3 p
  in sum <= triarea2 p1 p2 p3

let coordinates (t: t) (k: i32): maybe (i32, i32) =
  let (y_min, _y_max, x_min, x_max) = bounds t
  let width = (x_max - x_min + 1)
  let y = y_min + k / width
  let x = x_min + k % width
  in if point_in_triangle ((t.x0,t.y0),(t.x1,t.y1),(t.x2,t.y2)) (x,y)
     then #just (y,x) else #nothing

let generate (n_objs: i32) (h: i32) (w: i32) (rng: rng): (t, rng) =
  let max_h = h - 1
  let max_h' = i32.max (i32.min max_h 50) (max_h - n_objs / 100)
  let max_w = w - 1
  let max_w' = i32.max (i32.min max_w 50) (max_w - n_objs / 100)
  let (rng, height) = dist_int.rand (0, max_h') rng
  let (rng, width) = dist_int.rand (0, max_w') rng
  let (rng, y0) = dist_int.rand (0, h - 1 - height) rng
  let (rng, x0) = dist_int.rand (0, w - 1 - width) rng
  let (y1,x1) = (y0+height,x0+width)
  let (rng, y) = dist_int.rand (y0, y0+height) rng
  let (rng, x) = dist_int.rand (x0, x0+width) rng
  let (rng, kind) = dist_int.rand (0,3) rng
  let (y0,x0,y1,x1,y2,x2) =
    if kind == 0 then (y0,x0,y1,x,y,x1)
    else if kind == 1 then (y1,x0,y0,x,y,x1)
    else if kind == 2 then (y1,x1,y,x0,y0,x)
    else (y0,x1,y,x0,y1,x)
  let (rng, color) = rand_color rng
  in ({y0, x0, y1, x1, y2, x2, color}, rng)
