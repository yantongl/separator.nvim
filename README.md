# separator.nvim
 Provide a visual separator for code entities based on Treesitter info.

## TODO

* [x] use neovim extmark to show a separator
* [x] get buf file structure from Treesitter
* [ ] get buf file structure from LSP
* [x] show all separators
* [x] autocmd refresh on BufRead, BufEnter, BufWritePost
* allow config colors and style
  * [x] color: foreground color only
  * [x] style: solid line, dash, dot, double
  * [x] length: short for functions, long for classes
  * different types
    * namespace
    * class, struct, enum
    * embeded classes and enum
    * functions

## Inspired by

* [VSCode Separater](https://marketplace.visualstudio.com/items?itemName=alefragnani.separators)

