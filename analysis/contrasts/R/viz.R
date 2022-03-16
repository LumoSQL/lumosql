# Color palette -----------------------------------------------------------
colorme <- function(pos, alpha = 1) {
  x <- c("#9F0162", "#009F81", "#FF5AAF", "#00FCCF", "#8400CD", "#008DF9",
         "#00C2F9", "#FFB2FD", "#A40122", "#E20134", "#FF6E3A", "#FFC33B")

  adjustcolor(x[pos], alpha.f = alpha)
}

# ggplot specifics --------------------------------------------------------
init_viz      <- function() {
  theme_set(
    theme_bw() +
      theme(
        text = element_text(family = "URWHelvetica"),
        panel.grid       = element_blank(),
        plot.caption     = element_text(hjust = 0, family = "mono"),
        legend.position  = "bottom",
        strip.background = element_rect(fill = "gray90", color = "gray50",
                                        size = 0)
      )
  )
}
