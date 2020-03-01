import "../lib/github.com/diku-dk/lys/lys"
module core = import "stupidart"

type^ state = core.state

entry resize (h: i32) (w: i32) (s: state): state =
  core.resize h w s

entry key (e: i32) (key: i32) (s: state): state =
  let e' = if e == 0 then #keydown {key} else #keyup {key}
  in core.event e' s

entry mouse (buttons: i32) (x: i32) (y: i32) (s: state): state =
  core.event (#mouse {buttons, x, y}) s

entry wheel (dx: i32) (dy: i32) (s: state): state =
  core.event (#wheel {dx, dy}) s

entry step (td: f32) (s: state): state =
  core.event (#step td) s

entry render (s: state) =
  core.render s

entry init [h][w] (seed: i32) (image_source: [h][w]argb.colour): state =
  core.init seed image_source

entry text_content (s: state): (f32, bool) =
  core.text_content s

entry noninteractive [h][w] (seed: i32) (n_max_iterations: i32) (diff_goal: f32)
                            (image_source: [h][w]argb.colour):
                            ([h][w]argb.colour, i32, f32) =
  core.noninteractive seed n_max_iterations diff_goal image_source
