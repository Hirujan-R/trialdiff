## Generate a simple hex logo for trialdiff (base graphics, no dependencies).
## Run from the package root: Rscript data-raw/logo.R

dir.create("man/figures", showWarnings = FALSE, recursive = TRUE)

hex_xy <- function(scale = 1) {
  theta <- pi / 2 + seq(0, 2 * pi, length.out = 7)
  list(x = cos(theta) * scale, y = sin(theta) * scale)
}

png("man/figures/logo.png", width = 600, height = 692, res = 150,
    bg = "transparent")
par(mar = c(0, 0, 0, 0))
plot.new()
plot.window(c(-1.15, 1.15), c(-1.32, 1.32), asp = 1)

h <- hex_xy(1)
polygon(h$x, h$y, col = "#0A5C8C", border = NA)
h2 <- hex_xy(0.86)
polygon(h2$x, h2$y, col = "#0E6FA8", border = NA)

## a small "diff" motif: two arrows
arrows(-0.45, 0.42, 0.45, 0.42, length = 0.12, lwd = 5, col = "#FFFFFF")
arrows(0.45, 0.18, -0.45, 0.18, length = 0.12, lwd = 5, col = "#9FD3EE")

text(0, -0.18, "trialdiff", col = "white", font = 2, cex = 2.0)
text(0, -0.5, "data-cut change", col = "#CDE9F7", cex = 0.85)
text(0, -0.68, "& impact", col = "#CDE9F7", cex = 0.85)

dev.off()
message("Wrote man/figures/logo.png")
