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

let triarea2 ((y1,x1):pnt) ((y2,x2):pnt) ((y3,x3):pnt) : i32 =   -- twice the area of a triangle
  i32.abs(x1*(y2-y3)+x2*(y3-y1)+x3*(y1-y2))

let point_in_triangle ((p1,p2,p3):triangle) (p:pnt) : bool =
  let sum = triarea2 p1 p2 p + triarea2 p1 p3 p + triarea2 p2 p3 p
  in sum <= triarea2 p1 p2 p3

let coordinates (t: t) (k: i32): maybe (i32, i32) =
  let (y_min, _y_max, x_min, x_max) = bounds t
  let width = (x_max - x_min + 1)
  let p = (y_min + k / width,
	   x_min + k % width)
  in if point_in_triangle ((t.y0,t.x0),(t.y1,t.x1),(t.y2,t.x2)) p
     then #just p else #nothing

let randi (a:i32,b:i32) (rng:rng) = dist_int.rand (a,b) rng

let generate (count: i32) (h: i32) (w: i32) (rng: rng): (t, rng) =
  let max_h = h - 1
  let max_h' = i32.max (i32.min max_h 50) (max_h - count)
  let max_w = w - 1
  let max_w' = i32.max (i32.min max_w 50) (max_w - count)
  let (rng, height) = randi (0, max_h') rng
  let (rng, width) = randi (0, max_w') rng
  let (rng, vy0) = randi (0, h - 1 - height) rng    -- Position the upper left corner of
  let (rng, vx0) = randi (0, w - 1 - width) rng     -- the rectangle bounding the triangle
  let (vy1,vx1) = (vy0+height,vx0+width)            -- Calculate the lower right corner
  let (rng, vy) = randi (vy0, vy1) rng              -- Find intermediate values for x and y
  let (rng, vx) = randi (vx0, vx1) rng              -- for use for triangle corners
  let (rng, kind) = randi (0,3) rng
  let (y0,x0,y1,x1,y2,x2) =
    if kind == 0 then (vy0,vx0,vy1,vx,vy,vx1)
    else if kind == 1 then (vy1,vx0,vy0,vx,vy,vx1)
    else if kind == 2 then (vy1,vx1,vy,vx0,vy0,vx)
    else (vy0,vx1,vy,vx0,vy1,vx)
  let (rng, color) = rand_color rng
  in ({y0, x0, y1, x1, y2, x2, color}, rng)
