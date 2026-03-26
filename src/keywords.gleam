import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/set
import lustre/attribute
import lustre/element
import lustre/element/html
import simplifile

pub type Lang {
  Lang(name: String, source: String, keywords: List(String))
}

pub fn main() {
  let assert Ok(contents) = simplifile.read("keywords.json")
  let assert Ok(langs) = json.parse(contents, decode.list(lang_decoder()))
  let langs =
    list.sort(langs, fn(a, b) {
      int.compare(list.length(a.keywords), list.length(b.keywords))
    })
  let max =
    list.fold(langs, 1, fn(acc, lang) {
      int.max(acc, list.length(lang.keywords))
    })

  overlaps(langs)

  let page =
    html.html([], [
      html.head([], [
        html.title([], "Keywords by Language"),
        html.style(
          [],
          "
          body {font-family: monospace; margin: 2rem; overflow-x: auto; }
          .chart { display: inline-flex; gap: 2px; }
          .col { width: 28px; text-align: center; overflow: visible; }
          .label { font-size: 10px; white-space: nowrap; transform-origin: bottom left; transform: rotate(-30deg); }
          .count { font-size: 10px; color: #aaa; }
          .bar { width: 28px; display: flex; flex-direction: column; align-items: center; overflow: visible; }
          .kw { font-size: 9px; padding: 1px 0; white-space: nowrap; color: transparent; font-weight: bold; }
          .bar:hover { position: relative; z-index: 1; }
          .bar:hover .kw { color: #111; }
        ",
        ),
      ]),
      html.body([], [
        html.div([], [
          html.h2([attribute.attribute("style", "margin-bottom: 1.5rem")], [
            html.text("Number of Keywords by Language"),
          ]),
          html.div(
            [attribute.class("chart")],
            list.map(langs, fn(lang) {
              let count = list.length(lang.keywords)
              let color = bar_color(count, max)
              html.div([attribute.class("col")], [
                html.div([attribute.class("label")], [
                  html.a([attribute.href(lang.source)], [html.text(lang.name)]),
                ]),
                html.div([attribute.class("count")], [
                  html.text(int.to_string(count)),
                ]),
                html.div(
                  [
                    attribute.class("bar"),
                    attribute.attribute("style", "background: " <> color),
                  ],
                  list.map(lang.keywords, fn(kw) {
                    html.div([attribute.class("kw")], [html.text(kw)])
                  }),
                ),
              ])
            }),
          ),
        ]),
      ]),
    ])

  let output = element.to_document_string(page)
  let assert Ok(_) = simplifile.write("graph.html", output)
  io.println("Wrote graph.html")
}

fn bar_color(count: Int, max: Int) -> String {
  let t = int.to_float(count) /. int.to_float(int.max(max, 1))
  // cyan(180) -> blue(240) -> purple(300) -> red(360) -> orange(30) -> yellow(55)
  let hue = 180.0 +. t *. 235.0
  let h = case hue >=. 360.0 {
    True -> hue -. 360.0
    False -> hue
  }
  "hsl(" <> int.to_string(float.round(h)) <> ",85%,78%)"
}

fn lang_decoder() -> decode.Decoder(Lang) {
  use name <- decode.field("language", decode.string)
  use source <- decode.field("source", decode.string)
  use keywords <- decode.field("keywords", decode.list(decode.string))
  decode.success(Lang(name:, source:, keywords:))
}

fn overlaps(langs: List(Lang)) {
  list.index_map(langs, fn(lang1, idx) {
    langs
    |> list.take(idx)
    |> list.map(fn(lang2) {
      let s1 = set.from_list(lang1.keywords)
      let s2 = set.from_list(lang2.keywords)
      let both = set.intersection(s1, s2)
      #(set.size(both), lang2.name <> " are also in " <> lang1.name)
    })
  })
  |> list.flatten
  |> list.sort(fn(a, b) { int.compare(b.0, a.0) })
  |> list.take(15)
  |> list.map(fn(l) { io.println(int.to_string(l.0) <> " keywords in " <> l.1) })

  list.index_map(langs, fn(lang1, idx) {
    langs
    |> list.take(idx)
    |> list.map(fn(lang2) {
      let s1 = set.from_list(lang1.keywords)
      let s2 = set.from_list(lang2.keywords)
      let both = set.intersection(s1, s2)
      let smaller = int.min(set.size(s1), set.size(s2))
      let percent = int.to_float(set.size(both) * 100) /. int.to_float(smaller)
      let percent = float.to_precision(percent, 2)
      #(percent, lang2.name <> " are also in " <> lang1.name)
    })
  })
  |> list.flatten
  |> list.sort(fn(a, b) { float.compare(b.0, a.0) })
  |> list.take(15)
  |> list.map(fn(l) {
    io.println(float.to_string(l.0) <> "% of keywords in " <> l.1)
  })
}
