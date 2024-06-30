# nitpick-nvim

Neovim plugin for nitpick.

## Status

# Getting Started

nitpick has a philosophy of embedding in the ecosystem. If there is a canonical
tool that exists, nitpick will typically prefer to use that over rolling
something new. Most likely, these are already installed.

## Requirements

[diffview](https://github.com/sindrets/diffview.nvim)

## Setup

`require('nitpick').setup()`


# Usage

All commands are available through a single entry point: `Nitpick`.


## start_review

Starts a reivew. If provided a commit, use that as a starting point for the
review. This is useful when a review has not yet been conducted, or if including
older commits is desired.


## end_review

Compeletes the review and caches the ending commit to be the staritng point for
the next time `start_review` is called.
