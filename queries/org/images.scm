(link url: (expr) @image.src
  (#gsub! @image.src "^file:" "")
  (#match? @image.src "(png|jpg|jpeg|gif|bmp|webp|tiff|heic|avif|mp4|mov|avi|mkv|webm|pdf)$")
)
