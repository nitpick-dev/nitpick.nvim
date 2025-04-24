# lib

The lib module is intended to bridge libnitpick with the neovim plugin. Its main
purpose is to hide any complexity of calling to libnitpick. This includes any
non-lua idiomatic trickery to call across the ffi boundary and c allocations,
deallocations, and copies such that usage of `lib` _is_ idiomatic lua.

# init.lua

`init.lua` is the entry point and probably the place of most importance. This is
where we will actually make any of the calls over ffi. It is important to keep
this file as clean as possible. The main focus should be exporting libnitpick's
funcitons.

## utils

A c helper module.

As the overall goal of this module is to hide the complexity of ffi, nothing
from utils should be exported though `lib`. Avoid reaching to
`nitpick.lib.utils` directly.
