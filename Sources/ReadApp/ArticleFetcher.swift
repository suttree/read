import AppKit
import Foundation
import ReadCore
import WebKit

/// Loads pages headlessly through WebKit (never shown on screen) purely as
/// an extraction engine — the same rendering engine Safari uses, so pages
/// that need real JS execution to produce their content still work, unlike a
/// plain HTML-over-HTTP fetch.
@MainActor
final class ArticleFetcher {
    /// These fetches are throwaway extraction, not browsing — an ephemeral
    /// data store means no cookies or site data persist across launches
    /// (appropriate for pages you never actually see). That alone doesn't
    /// stop the Keychain prompt, though: WebKit backs `crypto.subtle`'s key
    /// wrapping with a Keychain item tied to the app's code signature even
    /// in an ephemeral session, and an ad-hoc dev build's signature changes
    /// on every rebuild, so macOS re-prompts each time some page's script
    /// touches it. These webviews never render anything a person sees, so
    /// there's no reason any page here needs real `crypto.subtle` — this
    /// script strips it out before any page code runs, which is what
    /// actually stops the prompt.
    private static func makeHeadlessWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let disableSubtleCrypto = WKUserScript(
            source: "try { Object.defineProperty(window.crypto, 'subtle', { value: undefined, configurable: true }); } catch (e) {}",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        configuration.userContentController.addUserScript(disableSubtleCrypto)
        return WKWebView(frame: .zero, configuration: configuration)
    }

    /// Up to `limit` headline-level stories from a tracked source's front
    /// page: the first few real h1/h2/h3 headings that carry a link,
    /// skipping ones inside nav/header/footer/aside boilerplate.
    ///
    /// Two things learned from inspecting real markup (theguardian.com) that
    /// shape this script: (1) a heading's own `innerText` often glues a
    /// category "kicker" onto the real headline with no separating space
    /// (e.g. "TariffsTrump announces…") because they're separate block
    /// children with layout-only spacing — a child element whose class
    /// contains "headline" is a much more reliable title when present.
    /// (2) the link and thumbnail for a headline are frequently *not* inside
    /// its immediate parent or even a `article`/`li` ancestor — they can sit
    /// several levels up, in a sibling subtree — so both need to search
    /// progressively wider ancestors rather than one fixed container.
    func fetchStories(from source: TrackedSource, limit: Int = 8) async -> [Story] {
        guard let url = URL(string: source.url) else {
            return []
        }
        let webView = Self.makeHeadlessWebView()
        await load(webView, url: url)

        let script = """
        (function() {
            // Modern component-based sites (Reddit's current UI is the main
            // example) render posts inside Shadow DOM custom elements, which
            // a plain querySelectorAll can't see into at all — this walks
            // into every shadow root it finds, recursively.
            function queryAllDeep(selector, root) {
                root = root || document;
                var results = Array.prototype.slice.call(root.querySelectorAll(selector));
                var all = root.querySelectorAll('*');
                for (var i = 0; i < all.length; i++) {
                    if (all[i].shadowRoot) {
                        results = results.concat(queryAllDeep(selector, all[i].shadowRoot));
                    }
                }
                return results;
            }

            // Consent-management platforms (OneTrust, Cookiebot, etc.) and
            // similar chrome widgets frequently mark their own banner
            // heading as a real h1/h2/h3 for accessibility, which otherwise
            // sails right through a plain heading scan.
            var boilerplatePhrases = [
                'manage your data', 'manage preferences', 'manage cookies', 'cookie preferences',
                'cookie policy', 'cookie settings', 'privacy policy', 'privacy settings',
                'terms of service', 'terms of use', 'sign up', 'sign in', 'log in', 'subscribe',
                'newsletter', 'accept all', 'accept cookies'
            ];
            function isBoilerplate(el) {
                return el.closest('nav, header, footer, aside, [class*="cookie" i], [id*="cookie" i], [class*="consent" i], [id*="consent" i], [class*="onetrust" i], [id*="onetrust" i]') !== null;
            }
            function isBoilerplateText(text) {
                var lower = text.toLowerCase();
                return boilerplatePhrases.some(function(phrase) { return lower.indexOf(phrase) !== -1; });
            }
            function titleOf(h) {
                var headlineEl = h.querySelector('[class*="headline" i]');
                if (headlineEl) {
                    var t = headlineEl.innerText.trim().replace(/\\s+/g, ' ');
                    if (t.length > 10) return t;
                }
                return h.innerText.trim().replace(/\\s+/g, ' ');
            }
            function findLink(h) {
                var el = h;
                for (var depth = 0; depth < 6 && el; depth++) {
                    var link = el.querySelector('a[href]');
                    if (link) return { link: link, container: el };
                    el = el.parentElement;
                }
                return null;
            }
            function findImage(container) {
                var el = container;
                var img = el.querySelector ? el.querySelector('img') : null;
                var climb = 0;
                while (!img && el.parentElement && climb < 3) {
                    el = el.parentElement;
                    img = el.querySelector('img');
                    climb++;
                }
                return img ? (img.currentSrc || img.src || null) : null;
            }

            var seen = {};
            var out = [];

            // Tier 1: proper headline markup (news homepages with real
            // h1/h2/h3 elements per story).
            var headings = queryAllDeep('h1, h2, h3');
            for (var i = 0; i < headings.length && out.length < \(limit); i++) {
                var h = headings[i];
                if (isBoilerplate(h)) continue;
                var text = titleOf(h);
                if (text.length < 15 || text.length > 160) continue;
                if (isBoilerplateText(text)) continue;
                if (seen[text]) continue;
                var found = findLink(h);
                if (!found) continue;
                seen[text] = true;
                out.push({ title: text, url: found.link.href, image: findImage(found.container) });
            }

            // Tier 2: link-aggregator style sites (Hacker News, Pinboard,
            // Bubbles, Reddit) that list stories as plain <a> links with no
            // heading markup at all. Only kicks in when tier 1 found
            // basically nothing, since it's a much cruder heuristic.
            if (out.length < 2) {
                var anchors = queryAllDeep('a[href]');
                for (var j = 0; j < anchors.length && out.length < \(limit); j++) {
                    var a = anchors[j];
                    if (isBoilerplate(a)) continue;
                    var href = a.getAttribute('href') || '';
                    if (href.indexOf('mailto:') === 0 || href.indexOf('tel:') === 0 || href.indexOf('javascript:') === 0 || href.indexOf('#') === 0) continue;
                    var linkText = a.innerText.trim().replace(/\\s+/g, ' ');
                    if (linkText.length < 15 || linkText.length > 160) continue;
                    // A title wrapped in parens is almost always a source
                    // attribution link sitting right next to the real one
                    // (Bubbles does exactly this), not a story itself.
                    if (linkText.charAt(0) === '(' && linkText.charAt(linkText.length - 1) === ')') continue;
                    if (isBoilerplateText(linkText)) continue;
                    if (seen[linkText]) continue;
                    if (!a.href) continue;
                    seen[linkText] = true;
                    out.push({ title: linkText, url: a.href, image: findImage(a) });
                }
            }

            return out;
        })();
        """
        let rows = decodeJSONArray(await evaluateJSON(webView, script: script))
        let sourceName = source.name.isEmpty ? (url.host ?? source.url) : source.name
        return rows.compactMap { row in
            guard let title = row["title"] as? String, let storyURL = row["url"] as? String else {
                return nil
            }
            return Story(
                title: title,
                storyURL: storyURL,
                sourceID: source.id,
                sourceName: sourceName,
                imageURL: row["image"] as? String
            )
        }
    }

    /// The full readable text of one story for its permalink page, plus a
    /// hero image if the page declares one via `og:image`.
    func fetchArticle(url: URL) async -> Article? {
        let webView = Self.makeHeadlessWebView()
        await load(webView, url: url)

        let script = """
        (function() {
            // Cookie-consent banners (OneTrust, Fides, Cookiebot, GDPR
            // notices generally) render their body copy as plain <p> tags
            // too, and often sit ahead of the real article in DOM order —
            // without this, "the first few paragraphs" can just be consent
            // legalese instead of the story.
            function isBoilerplate(el) {
                return el.closest('nav, header, footer, aside, [class*="cookie" i], [id*="cookie" i], [class*="consent" i], [id*="consent" i], [class*="onetrust" i], [id*="onetrust" i], [class*="gdpr" i], [id*="gdpr" i], [class*="fides" i], [id*="fides" i]') !== null;
            }
            var consentPhrases = [
                'we process your data', 'legitimate interest', 'transparency and consent framework',
                'this website uses cookies', 'this website uses essential cookies', 'manage your data',
                'manage preferences', 'accept all', 'accept cookies'
            ];
            function isConsentText(text) {
                var lower = text.toLowerCase();
                return consentPhrases.some(function(phrase) { return lower.indexOf(phrase) !== -1; });
            }

            var h1 = document.querySelector('h1');
            var titleText = h1 ? h1.innerText.trim() : document.title;
            var paragraphs = Array.from(document.querySelectorAll('article p, main p, p'))
                .filter(function(p) { return !isBoilerplate(p); })
                .map(function(p) { return p.innerText.trim(); })
                .filter(function(t) { return t.length > 40 && !isConsentText(t); });
            var seen = {};
            var uniqueParagraphs = paragraphs.filter(function(t) {
                if (seen[t]) return false;
                seen[t] = true;
                return true;
            });
            var ogImage = document.querySelector('meta[property="og:image"]');
            return {
                title: titleText,
                body: uniqueParagraphs.join('\\n\\n'),
                image: ogImage ? ogImage.getAttribute('content') : null
            };
        })();
        """
        guard let row = decodeJSONObject(await evaluateJSON(webView, script: script)),
              let title = row["title"] as? String,
              let body = row["body"] as? String,
              !body.isEmpty else {
            return nil
        }
        return Article(title: title, bodyText: body, imageURL: row["image"] as? String, sourceURL: url.absoluteString)
    }

    // MARK: - Headless page loading

    private final class LoadWaiter: NSObject, WKNavigationDelegate {
        private let continuation: CheckedContinuation<Void, Never>
        private var didResume = false

        init(continuation: CheckedContinuation<Void, Never>) {
            self.continuation = continuation
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            finish()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            finish()
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            finish()
        }

        func timeoutIfNeeded() {
            finish()
        }

        private func finish() {
            guard !didResume else {
                return
            }
            didResume = true
            continuation.resume()
        }
    }

    /// A page that hangs (slow ads, a tracking script that never settles)
    /// shouldn't block the whole refresh — fall back to whatever loaded
    /// after a timeout rather than waiting forever.
    private func load(_ webView: WKWebView, url: URL, timeout: TimeInterval = 15) async {
        var waiter: LoadWaiter?
        await withCheckedContinuation { continuation in
            let w = LoadWaiter(continuation: continuation)
            waiter = w
            webView.navigationDelegate = w
            webView.load(URLRequest(url: url))
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                w.timeoutIfNeeded()
            }
        }
        _ = waiter
    }

    private func decodeJSONArray(_ data: Data?) -> [[String: Any]] {
        guard let data, let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return array
    }

    private func decodeJSONObject(_ data: Data?) -> [String: Any]? {
        guard let data else {
            return nil
        }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    /// Re-serializes the JS result into `Data` before crossing the
    /// continuation boundary — `Any` from `evaluateJavaScript`'s completion
    /// isn't Sendable, but `Data` is, so this sidesteps the data-race check
    /// entirely instead of suppressing it.
    ///
    /// Also guards with its own timeout, separate from the page-load one:
    /// `evaluateJavaScript`'s completion handler can simply never fire on
    /// some pages (a stuck JS context, a blocked script) — without this, one
    /// such page would hang its whole enrichment batch forever, since a
    /// `TaskGroup` batch only finishes once every task in it does.
    private func evaluateJSON(_ webView: WKWebView, script: String, timeout: TimeInterval = 8) async -> Data? {
        final class ResumeGuard {
            var didResume = false
        }
        let resumeGuard = ResumeGuard()
        return await withCheckedContinuation { continuation in
            func resumeOnce(_ value: Data?) {
                guard !resumeGuard.didResume else {
                    return
                }
                resumeGuard.didResume = true
                continuation.resume(returning: value)
            }
            webView.evaluateJavaScript(script) { result, _ in
                guard let result, JSONSerialization.isValidJSONObject(result) else {
                    resumeOnce(nil)
                    return
                }
                resumeOnce(try? JSONSerialization.data(withJSONObject: result))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                resumeOnce(nil)
            }
        }
    }
}
