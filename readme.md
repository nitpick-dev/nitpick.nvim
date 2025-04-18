# nitpick-nvim

Neovim plugin for nitpick.

**Notice:** Development for this plugin is done in the
[nitpick-dev/editors](https://github.com/nitpick-dev/editors/tree/main/src/plugins/nvim)
monorepo and released to
[nitpick-dev/nitpick.nvim](https://github.com/nitpick-dev/nitpick.nvim).

**Status:** it might work ¯\\_(ツ)_/¯

# Getting Started

## Installation

### Lazy

```lua
return {
    "nitpick-dev/nitpick.nvim",
    build = "sh install.sh",
}
```

### packer / pckr

```lua
{ "nitpick-dev/nitpick.nvim", run = "sh install.sh" }
```

### paq

```lua
{ "nitpick-dev/nitpick.nvim", build = "sh install.sh" }
```

## Requirements

nitpick has a philosophy of embedding in the ecosystem. If there is a canonical
tool that exists, nitpick will typically prefer to use that over rolling
something new. In most cases, these are plugings that would already be
installed.


**Note:** For all of the below requirements, if multiple are listed under a
section, only one needs to be installed; nitpick will automatically detect which
one to use.

### Diffing tool

A diffing tool is required to display the diffs while conducting a review.

#### Supported

[diffview](https://github.com/sindrets/diffview.nvim)

### Pickers

When no previous review has been detected, nitpick will prompt the user for a
starting point using a picker.

#### Supported

[Fzf-Lua](https://github.com/ibhagwan/fzf-lua)

[telescope](https://github.com/nvim-telescope/telescope.nvim)


## Setup

`require('nitpick').setup()`

If you are a delveloper, the setup method can take a set of options which
include a path to the lib binary to override the default.

## Authentication

nitpick does not host any source code. Instead, we rely on a platform like
GitHub (which is currently the only host that is supported). In order to access
repositories, it is required to provide a PAT. Eventually, we will build in an
auth mechanism, but for now you need to run the command
`Nitpick authorize github <YOUR_PATH`. We have tab completions through github.

If you would like to edit, view, or delete the pat, it is currently stored in
`$HOME/.local/share/nitpick/config`. You may edit this file, but it may cause
unexpected issues with the rest of nitpick.

# Usage

Most commands are available through a single entry point: `Nitpick`.

## start [commit]

Starts a reivew.

If provided a commit, use that as a starting point for the review. This is
useful when a review has not yet been conducted, or if including older commits
is desired. This command does not affect the state of the reviews. Quitting the
review (`DiffviewClose`, `:qa!`, etc) will preserve the previous commit.

When a previous review has not been detected, a [picker](#pickers) for commits
will open. The selected commit will become the starting point for the review.
Similar to passing a speific commit to the `Nitpick start`, this will not affect
the overall state of reviews. Unless `Nitpick end` was invoked to mark the next
starting point, a picker will be presented on the next `Nitpick start`.


## end

Ends a reivew. The state of the review is updated to the HEAD commit and will
become the starting point for the next `Nitpick start`.
