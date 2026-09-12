# Knowledge

Reference material for developing this AddOn: what the client actually exposes, how other people
solved the same problems, and what a port to another client would have to deal with.

This is not documentation of this AddOn — that is `SPEC.md`. It is the notebook behind it.

| | |
| --- | --- |
| [`CLIENT-SOURCE.md`](CLIENT-SOURCE.md) | **Start here.** Blizzard's own interface source for build 5.5.4.69585, how to fetch it, which file each flavour really loads, and the things reading it settled |
| [`api-index.txt`](api-index.txt) | Every system, function and event the client documents. 533 systems, 4,590 functions, 1,483 events |
| [`api-signatures.txt`](api-signatures.txt) | Full signatures and structures, for the systems this AddOn touches |
| [`REFERENCE-ADDONS.md`](REFERENCE-ADDONS.md) | Five AddOns worth reading, what to take from each, and what not to copy |
| [`RETAIL.md`](RETAIL.md) | What a retail port would have to remove. All of it unverified, and marked as such |
| `fetch_client_source.sh` | Clones a client's interface source and rebuilds the index |
| `build_api_index.lua` | Generates the two index files from the client's own API documentation |

## The rule this is here to serve

Two answers to "what does this client do" are allowed: **the source says so**, with a file and a
line, or **the game said so**, with a probe and a log. Memory is not a third answer. The rule
predates this directory; what this directory changes is that the first of the two is now a clone
away instead of a round trip through someone's evening.

Where the two disagree, the game wins and the disagreement gets written down.

## Rebuilding after a patch

```sh
dev/knowledge/fetch_client_source.sh              # classic, the progression client
dev/knowledge/fetch_client_source.sh live         # retail
```

The script fetches the source, prints the build it got, and regenerates `api-index.txt` and
`api-signatures.txt` in place. Commit the regenerated files with the interface bump, so the index
in the repository always describes the client in the `.toc`.

## The wiki

<https://warcraft.wiki.gg/wiki/World_of_Warcraft_API> and
<https://warcraft.wiki.gg/wiki/World_of_Warcraft_API/Classic> are the community reference, and the
`Category:API namespaces` tree under them breaks the `C_*` namespaces down one page each.

**Both are blocked from this development environment**, along with `wowpedia.fandom.com`, so nothing
here is drawn from them. That turned out not to cost anything, because the client ships its own
generated API documentation and it is better for this purpose: it is exact for one build, it says
what each argument and return is called and whether it is nilable, and it cannot be out of date for
a client it came out of. The wiki's advantage is prose — what a function is *for*, which versions
changed it, and what breaks — and that is worth reading on a machine that can reach it when a
signature alone is not enough.

Where the two conflict about this client, the generated documentation is right.
