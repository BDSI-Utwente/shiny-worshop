library(shiny)
library(tidyverse)

# Load and pre-process the required data.
data("billboard")
billboard_long <- billboard %>%
    # The billboard dataset is a textbook example of a 'wide' dataset, we use
    # the example code from the `pivot_wider(...)` function to create a 'long'
    # dataset containing one row for each track, for each week that it listed
    # in the charts.
    pivot_longer(
        cols = starts_with("wk"),
        names_to = "week",
        names_prefix = "wk",
        values_to = "rank",
        values_drop_na = TRUE
    ) %>%
    # We create a 'full_title' field to aid searching later, and do some clean-
    # up of the date fields.
    mutate(
        full_title = paste(artist, "-", track),
        date = lubridate::ymd(date.entered) + lubridate::weeks(week),
        week = lubridate::week(date)
    )

# Define UI for an application that allows the user to select an artist and track,
# and then shows a lineplot of how that track charted over time. See the example
# on reactive values for more documentation on UI functions.
ui <- fluidPage( # Application title
    titlePanel("2000 top charts"),
    sidebarLayout(
        sidebarPanel(
            # Instead of 'hard coding' choices, we instead pull the names of
            # artists in the dataset to populate the list of choices.
            # We also add an empty element, the name of which will be used as
            # a placeholder in the UI.
            selectInput(
                "artist",
                "Select artist...",
                c(
                    `Select artist to show tracks...` = "",
                    billboard_long %>% pull(artist) %>% unique() %>% sort()
                )
            ),
            # Pull tracks to create track choices. Note that since we don't yet
            # know the chosen artist when the UI is first created, we cannot
            # filter track choices here.
            selectInput(
                "track",
                "Select track...",
                billboard_long %>% pull(track) %>% unique() %>% sort()
            ),

            # As discussed in the debounce example, we use a button to trigger
            # output updates.
            actionButton("do_search", label = "Go!")
        ),
        mainPanel(plotOutput("plot"))
    )
)

server <- function(input, output, session) {
    # We create a reactive value to filter our 'raw' data based on the users'
    # artist and track choices.
    # Note that shiny only updates reactives when needed, e.g., when it is used
    # in other reactives. In this case, `data()` is only used in `output$plot`
    # (defined below), so will only be updated when `output$plot` is updated.
    # We could (and arguably should) explicitly use `bindEvent(...)` to only
    # update the data when the user presses the `search` button.
    data <- reactive({
        billboard_long %>% filter(artist == input$artist, track == input$track)
    })

    # Render a lineplot showing the chart position of the chosen artist and track
    # over time.
    output$plot <- renderPlot({
        if (is.null(data())) {
            return()
        }
        ggplot(
            data(),
            aes(
                x = date,
                y = rank,
                colour = full_title,
                linetype = artist,
                group = full_title
            )
        ) +
            geom_point() +
            geom_line() +
            scale_y_reverse(limits = c(100, 1))
    }) %>%
        # We use bindEvent(...) to explicitly tell shiny to react only to changes
        # in `input$do_search`, i.e., when the search button is pressed.
        # Not doing so would cause the plot to be updated whenever `data()` changes
        # (or technically, when `data()` is outdated, triggering an update).
        bindEvent(input$do_search)
}

# Run the application
shinyApp(ui = ui, server = server)
