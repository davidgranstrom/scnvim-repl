# scnvim-repl

Use an external terminal as the sclang post window, like the classic `scvim` plugin.

## Requirements

* SuperCollider
* Ruby

## Installation

* Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```
{ 'davidgranstrom/scnvim-repl', lazy = true }
```

Load the extension **after** the call to `scnvim.setup`.

```lua
scnvim.setup{...}

scnvim.load_extension 'repl'
```

## Configuration

```lua
scnvim.setup {
  extensions = {
    repl = {
      term_cmd = {'open', '-a', 'Ghostty.app'}
    },
  },
}
```

## License

The ruby program is copied from the original [scvim](https://github.com/supercollider/scvim) repo with minor modifications, see `ruby/COPYING` for the full the license (GPLv3).

```
scnvim-repl - Use an external terminal as the sclang post window.
Copyright © 2026 David Granström

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
```
