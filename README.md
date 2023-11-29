# separator.nvim
 Provide a visual separator for code entities based on Treesitter info.

## TODO

* [x] use neovim extmark to show a separator
* get buf file structure from Treesitter
* show all separators
* autocmd refresh on BufRead, BufEnter, BufWritePost
* allow config colors and style
  * color: foreground color only
  * style: line, dash, dot
  * length: short for functions, long for classes
    * namespace
    * class, struct, enum
    * embeded classes and enum
    * functions

## Inspired by

* [VSCode Separater](https://marketplace.visualstudio.com/items?itemName=alefragnani.separators)

