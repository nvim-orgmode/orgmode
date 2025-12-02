(link url: (expr) @image.src
  (#gsub! @image.src "^file:" "")
  (#match? @image.src "(png|jpg|jpeg|gif|bmp|webp|tiff|heic|avif|mp4|mov|avi|mkv|webm|pdf|svg)$")
)

(block
  name: (expr) @name
  parameter: (expr) @lang
  contents: (contents) @image.content
  (#match? @name "(src|SRC)")
  (#match? @lang "(math|latex)")
  (#set! injection.language "latex")
  (#set! image.ext "math.tex"))


(block
  name: (expr) @name
  contents: (contents) @image.content
  (#match? @name "(equation|EQUATION)")
  (#set! injection.language "latex")
  (#set! image.ext "math.tex"))

(latex_env
  (#set! injection.language "latex")
  (#set! image.ext "math.tex")) @image.content @image

(inline_math_block
  (#set! injection.language "latex")
  (#set! image.ext "math.tex")) @image.content @image

(display_math_block
  (#set! injection.language "latex")
  (#set! image.ext "math.tex")) @image.content @image
