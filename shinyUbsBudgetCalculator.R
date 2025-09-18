library(shiny)
library(pdftools)
library(stringr)
library(dplyr)
library(ggplot2)

ui <- fluidPage(
  titlePanel("UBS PDF Parser"),
  
  sidebarLayout(
    sidebarPanel(
      fileInput("pdf_file", "Wähle ein UBS PDF", accept = ".pdf"),
      textInput("filter_text", "Filter Text (optional, z.B. Coop)", value = "")
    ),
    
    mainPanel(
      tableOutput("tx_table"),
      verbatimTextOutput("sum_text"),
      plotOutput("balance_plot")
    )
  )
)

server <- function(input, output, session) {
  
  parsed_data <- reactive({
    req(input$pdf_file)
    file <- input$pdf_file$datapath
    pages <- pdf_text(file)
    
    clean_amount <- function(x) {
      if (is.na(x) || x == "") return(NA_real_)
      x <- str_replace_all(x, "'", "")
      x <- str_replace(x, ",", ".")
      neg <- str_detect(x, "^\\(.*\\)$")
      x <- str_remove_all(x, "[()]")
      num <- as.numeric(x)
      if (neg) num <- -num
      num
    }
    
    all_lines <- unlist(lapply(pages, function(p) trimws(str_split(p, "\n")[[1]])))
    all_lines <- all_lines[!str_detect(all_lines,
                                       regex("Displayed in Assets online|UBS Switzerland AG|Page \\d+/|Opening balance|Closing balance|Turnover|For all your questions",
                                             ignore_case = TRUE))]
    
    date_regex <- "^\\d{2}\\.\\d{2}\\.\\d{4}"
    blocks <- list()
    i <- 1
    while (i <= length(all_lines)) {
      ln <- all_lines[i]
      if (str_detect(ln, date_regex)) {
        buf <- ln
        j <- i + 1
        while (j <= length(all_lines) && !str_detect(all_lines[j], date_regex)) {
          if (all_lines[j] != "") buf <- paste(buf, all_lines[j], sep = " ")
          j <- j + 1
        }
        blocks <- append(blocks, buf)
        i <- j
      } else {
        i <- i + 1
      }
    }
    
    decimal_pat <- "\\(?-?[0-9'\\.,]+[\\.,][0-9]{2}\\)?"
    results <- list()
    for (blk in blocks) {
      datum <- str_extract(blk, date_regex)
      rest  <- str_trim(str_remove(blk, fixed(datum)))
      nums <- str_extract_all(rest, decimal_pat)[[1]]
      Betrag <- if(length(nums) >= 1) clean_amount(nums[1]) else NA_real_
      Balance <- if(length(nums) >= 2) clean_amount(nums[length(nums)]) else NA_real_
      text <- rest
      if (!is.na(Betrag)) text <- str_remove(text, fixed(nums[1]))
      if (!is.na(Balance) && length(nums) > 1) text <- str_remove(text, fixed(nums[length(nums)]))
      text <- str_squish(text)
      results <- append(results, list(tibble(
        Datum   = datum,
        Text    = text,
        Betrag  = Betrag,
        Balance = Balance
      )))
    }
    
    tx_df <- bind_rows(results) %>% filter(!is.na(Betrag))
    
    # Filter anwenden, falls Text eingegeben wurde
    if (nchar(input$filter_text) > 0) {
      filtered_df <- tx_df %>% filter(str_detect(Text, regex(input$filter_text, ignore_case = TRUE)))
      return(list(df = filtered_df, sum = sum(filtered_df$Betrag, na.rm = TRUE)))
    } else {
      return(list(df = tx_df, sum = NA))
    }
  })
  
  output$tx_table <- renderTable({
    parsed_data()$df
  })
  
  output$sum_text <- renderText({
    sum_val <- parsed_data()$sum
    if (!is.na(sum_val)) {
      paste("Summe der gefilterten Beträge:", round(sum_val, 2))
    } else {
      ""
    }
  })
  
  output$balance_plot <- renderPlot({
    df <- parsed_data()$df
    if(nrow(df) > 0) {
      ggplot(df, aes(x = as.Date(Datum, format="%d.%m.%Y"), y = Balance)) +
        geom_line() + geom_point() +
        theme_minimal() + labs(title = "Balance Verlauf", x = "Datum", y = "Balance")
    }
  })
  
}

shinyApp(ui, server)
