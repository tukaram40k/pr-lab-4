require 'nyaplot'

# sample data
x = [1, 2, 3, 4, 5, 6, 7]
y = [3, 7, 4, 9, 6, 56, 44]

plot = Nyaplot::Plot.new
plot.add(:line, x, y)

# show in browser
plot.export_html("plots/line_chart.html")
puts "Chart saved to plots/line_chart.html"
