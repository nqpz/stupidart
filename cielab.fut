type color = u32

type tup3 = (f32, f32, f32)
type bounds = {min: f32, max: f32}
type cielab_bounds = {l: bounds, a: bounds, b: bounds}


let srgb_to_xyz ((r, g, b): tup3): tup3 =
  let upd w = if w > 0.04045
              then ((w + 0.055 ) / 1.055)**2.4
              else w / 12.92
  let (r, g, b) = (upd r, upd g, upd b)
  let x = r * 0.4124 + g * 0.3576 + b * 0.1805
  let y = r * 0.2126 + g * 0.7152 + b * 0.0722
  let z = r * 0.0193 + g * 0.1192 + b * 0.9505
  in (x, y, z)

let xyz_to_srgb ((x, y, z): tup3): tup3 =
  let r = x * 3.2406 + y * (-1.5372) + z * (-0.4986)
  let g = x * (-0.9689) + y * 1.8758 + z * 0.0415
  let b = x * 0.0557 + y * (-0.2040) + z * 1.0570
  let upd w = if w > 0.0031308
              then 1.055 * (w**(1 / 2.4)) - 0.055
              else 12.92 * w
  in (upd r, upd g, upd b)

let xyz_to_cielab ((x, y, z): tup3): tup3 =
  let upd w = if w > 0.008856
              then w**(1/3)
              else (7.787 * w) + (16 / 116)
  let (x, y, z) = (upd x, upd y, upd z)
  let l = (116 * y) - 16
  let a = 500 * (x - y)
  let b = 200 * (y - z)
  in (l, a, b)

let cielab_to_xyz ((l, a, b): tup3): tup3 =
  let y = (l + 16) / 116
  let x = a / 500 + y
  let z = y - b / 200
  let upd w = if w**3 > 0.008856
              then w**3
              else (w - 16 / 116) / 7.787
  in (upd x, upd y, upd z)

let srgb_to_cielab: tup3 -> tup3 = srgb_to_xyz >-> xyz_to_cielab
let cielab_to_srgb: tup3 -> tup3 = cielab_to_xyz >-> xyz_to_srgb

let cielab_bounds: cielab_bounds =
  {l={min=0, max=100},
   a={min= -92.245224, max=91.081085},
   b={min= -113.363686, max=91.588272}}

let cielab_pack_factor = 9.98f32

let nonneg (k: i32): u32 =
  if k < 0 then 0 else u32.i32 k

let cielab_pack ((l, a, b): tup3): color =
  -- 10 bits
  let li = nonneg (t32 (cielab_pack_factor * l))
  -- 11 bits
  let ai = nonneg (t32 (cielab_pack_factor * (a - cielab_bounds.a.min)))
  -- 11 bits
  let bi = nonneg (t32 (cielab_pack_factor * (b - cielab_bounds.b.min)))
  in li << 22 | ai << 11 | bi

let cielab_unpack (c: color): tup3 =
  let bi = c & 0b11111111111
  let ai = (c >> 11) & 0b11111111111
  let li = c >> 22
  let b = f32.u32 bi / cielab_pack_factor + cielab_bounds.b.min
  let a = f32.u32 ai / cielab_pack_factor + cielab_bounds.a.min
  let l = f32.u32 li / cielab_pack_factor + cielab_bounds.l.min
  in (l, a, b)

let cielab_delta ((l1, a1, b1): tup3) ((l2, a2, b2): tup3): f32 =
  f32.sqrt ((l1 - l2)**2 + (a1 - a2)**2 + (b1 - b2)**2)
