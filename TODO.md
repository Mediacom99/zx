# TODO General
- copy project structure and build.zig from notable projects (ghostty, zig itself)
- fix fuzzy commented-out fuzzy tests
- finish FuzzyMatchV1 algorithm.
- implement FuzzyMatchV2 version.

# TODO WIP V1

- make all indexes usize, i32 is only for actual unicode chars
- remove i32, we can just use u21 and ?u21 when -1 is used
- figure out how to return result (u21 slice in case of unicode, otherwise byte slice ?)
- remove all anonymous structs, everything should be defined
- implement calculateScore
- implement case insensitivity
