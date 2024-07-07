# nitpick-nvim

Neovim plugin for nitpick.

**Notice:** Development for this plugin is done in the
[nitpick-dev/editors](https://github.com/nitpick-dev/editors/tree/main/nvim)
monorepo and released to
[nitpick-dev/nvim](https://github.com/nitpick-dev/nvim).

**Status:** it might work ¯\\_(ツ)_/¯

# Getting Started

nitpick has a philosophy of embedding in the ecosystem. If there is a canonical
tool that exists, nitpick will typically prefer to use that over rolling
something new. Most likely, these are already installed.

## Requirements

### Diffing tool

A diffing tool is required to display the diffs while conducting a review.

#### Supported

[diffview](https://github.com/sindrets/diffview.nvim)

### Pickers

When no previous review has been detected, nitpick will prompt the user for a
starting point using a picker.

### Supported

[Fzf-Lua](https://github.com/ibhagwan/fzf-lua)
[telescope](https://github.com/nvim-telescope/telescope.nvim)


## Setup

`require('nitpick').setup()`


# Usage

All commands are available through a single entry point: `Nitpick`.


## start [commit]

Starts a reivew.

If provided a commit, use that as a starting point for the review. This is
useful when a review has not yet been conducted, or if including older commits
is desired. This command does not affect the state of the reviews. Quiting the
review (`DiffviewClose`, `:qa!`, etc) will preserve the previous commit.

When a previous review has not been detected, a [picker](#pickers) for commits
will open. The selected commit will become the starting point for the review.
Similar to passing a speific commit to the `Nitpick start`, this will not affect
the overall state of reviews. Unless `Nitpick end` was invoked to mark the next
starting point, a picker will be presented on the next `Nitpick start`.


## end

Ends a reivew. The state of the review is updated to the HEAD commit and will
become the starting point for the nexe `Nitpick start`.
