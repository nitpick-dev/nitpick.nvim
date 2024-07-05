# nitpick-nvim

Neovim plugin for nitpick.

**Notice:** Development for this plugin is done in the
[nitpick-dev/editors](https://github.com/nitpick-dev/editors/tree/main/nvim)
monorepo and released to
[nitpick-dev/nvim](https://github.com/nitpick-dev/nvim).

**Status:** it might work ¯\_(ツ)_/¯

# Getting Started

nitpick has a philosophy of embedding in the ecosystem. If there is a canonical
tool that exists, nitpick will typically prefer to use that over rolling
something new. Most likely, these are already installed.

## Requirements

### Diffing tool

A diffing tool is required to start reviews.

#### Supported

[diffview](https://github.com/sindrets/diffview.nvim)


## Setup

`require('nitpick').setup()`


# Usage

All commands are available through a single entry point: `Nitpick`.


## start

Starts a reivew. If provided a commit, use that as a starting point for the
review. This is useful when a review has not yet been conducted, or if including
older commits is desired.


## end

Compeletes the review and caches the ending commit to be the staritng point for
the next time `start` is called.
