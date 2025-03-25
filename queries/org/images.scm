(link url: (expr) @image.src
  (#gsub! @image.src "^file:" "")
  (#match? @image.src "(png|jpg|jpeg|gif|bmp|webp|tiff|heic|avif|mp4|mov|avi|mkv|webm|pdf)$")
)

(block
  name: (expr) @name
  parameter: (expr) @lang
  contents: (contents (expr) @image.content)
  (#match? @name "(src|SRC)")
  (#eq? @lang "(math|latex)")
  (#set! injection.language "latex")
  (#set! image.ext "math.tex"))
