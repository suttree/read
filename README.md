# Read

A native macOS magazine-style headlines reader. Track the sites you care
about, get a paginated feed of stories pulled straight from their front
pages, vote stories up or down, and let a locally-trained ranker start
surfacing what you actually want to read.

There's no server and no external API in the loop for the reading
experience itself — story extraction and full-article fetching both happen
through a headless `WKWebView` (the same engine as Safari), and the
Naive Bayes ranker trains entirely on-device from your votes.

## Features

- **Tracked sources** — add any site's URL in Settings; Read pulls headline
  links from its front page on refresh.
- **Extraction that handles real-world markup** — headings with embedded
  kicker text, images/links sitting several DOM levels away from their
  headline, cookie-consent banners masquerading as content, link-aggregator
  sites with no heading markup at all (Hacker News/Pinboard/Bubbles-style),
  and Shadow DOM–rendered posts (Reddit's current UI).
- **A local article cache** — the last 100 fetched articles are cached to
  disk and reused on the next refresh instead of re-fetched, so refreshing
  the same sources repeatedly is fast.
- **Permalink pages** — full extracted article text, with a link back to
  the original. Opening one marks the story read.
- **Unread / Saved / All** — a filter at the top of the feed. Unread hides
  anything already opened; hit the heart icon (or `l` on a permalink) to
  save a story for later regardless of read state; `h` on a permalink
  toggles that story's read/unread status directly.
- **Voting + ranking** — up/down vote any story; once you've voted enough
  in both directions, a Naive Bayes classifier (trained on title words,
  a bounded excerpt of article text, and named entities extracted on-device
  via Apple's NaturalLanguage framework) starts reordering the feed by
  predicted interest.
- **Pagination** — 5 stories per page, with prev/next controls at both the
  top and bottom of the list.
- **Keyboard navigation** — vim-style `j`/`k` to move between cards on the
  feed, and `j`/`k` to step to the next/previous story on a permalink page;
  `⌘[`/`⌘]` for browser-style story back/forward, and Backspace to jump
  straight from a permalink back to the feed.
- **Password lock screen** — the app is protected by a password you choose
  (AES-GCM, HKDF-derived key, no recovery if lost), with the same
  auto-lock-after-10-minutes behavior as Fork. No Keychain involved, so no
  surprise system authorization prompts from an unsigned dev build.
- **Themes** — five palettes (Default plus four pastels), each with its own
  header tint, background texture, and app icon color.

## Building

```bash
swift build
./Scripts/build-app.sh   # produces .build/Read.app
open .build/Read.app
```

Requires macOS 14+. This isn't an Xcode project — `build-app.sh` assembles
the `.app` bundle manually (there's no code signing, so expect a Gatekeeper
prompt on first launch).

## Project layout

- `Sources/ReadCore` — pure Swift/Foundation: models, stores, the Naive
  Bayes ranker, entity extraction. No AppKit/WebKit, so it's plain and
  testable in isolation.
- `Sources/ReadApp` — the SwiftUI app: views, the headless-WebKit article
  fetcher, and the theming system.

## Known limitations

- No AI summarization — cards show a real excerpt (opening paragraphs of
  the actual article), not a generated summary. Considered and deliberately
  skipped for cost/latency reasons; see the ranker's docs if you want to
  revisit that.
- The ranker is title/excerpt/entity-based only — no image or full-article
  signal beyond the bounded excerpt.
- No sentiment analysis in the ranker (doesn't fit the bag-of-tokens model
  well, and tone doesn't reliably predict topical interest anyway).
- Extraction heuristics are just that — heuristics. New sites with unusual
  markup may need their own fix, the same way Guardian/404 Media/Ars
  Technica/Bubbles/Pinboard/Reddit each needed one along the way.
