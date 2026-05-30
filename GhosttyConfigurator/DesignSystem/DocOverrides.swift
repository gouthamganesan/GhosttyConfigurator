import Foundation

/// Curated, hand-written doc overrides for `DocTooltip` rows where the
/// schema-derived text is too generic (or absent). Looked up by the *full*
/// docKey the pane passes — including any parenthetical disambiguation like
/// `font-feature (+/-liga)`. When no override exists, DocTooltip falls back
/// to the schema entry.
///
/// Keep entries here when the surface row is more specific than a single
/// Ghostty config key (e.g. one row per OpenType feature tag, all routing
/// through the same `font-feature` key).
enum DocOverrides {
    struct Entry {
        let title: String
        let body: String
        let link: URL?
    }

    static func lookup(_ key: String) -> Entry? {
        table[key]
    }

    // MARK: - Table

    private static let table: [String: Entry] = [
        // MARK: OpenType — per-feature

        "font-feature (+/-liga)": Entry(
            title: "liga — Standard ligatures",
            body: """
            Substitutes specific character pairs with a single combined glyph the \
            font designer drew. In monospace programming fonts this is usually \
            paired with `calt` — together they turn sequences like `->` into →, \
            `!=` into ≠, `=>` into ⇒, and so on.

            Fonts that ship programming ligatures (Fira Code, JetBrains Mono, \
            Cascadia Code, Iosevka, MonoLisa, Berkeley Mono…) tend to be the \
            ones where this matters. Plain monospace fonts have no ligatures to \
            substitute, so the toggle is a no-op for them.

            Disable if you find the visual substitutions distracting, or if \
            your font does odd substitutions you don't want.
            """,
            link: URL(string: "https://learn.microsoft.com/en-us/typography/opentype/spec/features_ko#liga")
        ),

        "font-feature (+/-calt)": Entry(
            title: "calt — Contextual alternates",
            body: """
            Picks a different glyph for a character based on what surrounds it. \
            This is the feature most programming fonts actually use to render \
            ligatures (despite the name `liga`) — the substitution depends on \
            neighbours, which is why `==` reads as a single glyph but the `=` \
            in `a = b` stays separate.

            Also drives things like contextual stylistic swaps — e.g. an \
            uppercase `O` rendered slightly differently when it's next to other \
            uppercase letters.

            For most programming fonts, turning off `calt` disables more \
            ligatures than turning off `liga`. If you want a "purely textual" \
            terminal with no glyph mashups, disable both.
            """,
            link: URL(string: "https://learn.microsoft.com/en-us/typography/opentype/spec/features_ae#calt")
        ),

        "font-feature (+/-dlig)": Entry(
            title: "dlig — Discretionary ligatures",
            body: """
            Decorative, optional ligatures the font designer marked as \
            "off-by-default" because they're stylistic rather than functional. \
            Examples in display/serif fonts: ornate `ct`, double-`T` joining, \
            stylized `Th`.

            Most monospace programming fonts don't define `dlig` substitutions \
            — programming ligatures live under `liga`/`calt` instead. Turning \
            this on is harmless when unsupported but worth checking your font \
            with a tool like fontdrop.info to see whether it has any.
            """,
            link: URL(string: "https://learn.microsoft.com/en-us/typography/opentype/spec/features_ko#dlig")
        ),

        "font-feature (+/-hlig)": Entry(
            title: "hlig — Historical ligatures",
            body: """
            Old-typography ligatures evoking pre-modern letterpress styles — \
            the classic `ſt` long-s + t, `ct` joins, and similar archaic \
            forms. Common in serif text faces designed for prose; almost \
            never present in monospace fonts intended for code.

            Safe to leave off in a terminal. Only enable if your font \
            explicitly advertises historical alternates and you want that \
            aesthetic in screen text.
            """,
            link: URL(string: "https://learn.microsoft.com/en-us/typography/opentype/spec/features_fj#hlig")
        ),

        "font-feature (tnum/pnum/onum/lnum)": Entry(
            title: "Numerals — figure style",
            body: """
            Controls how digits look. The picker is exclusive — choosing one \
            mode clears the others.

              • **Tabular** (`tnum`) — every digit takes the same horizontal \
            space, so columns of numbers line up. Best default for a terminal: \
            tables, log timestamps, and aligned output stay readable.

              • **Proportional** (`pnum`) — each digit uses its natural width \
            (narrow `1`, wide `0`). Looks nicer in prose, breaks alignment in \
            tabular output.

              • **Old-style** (`onum`) — mixed-height digits with ascenders \
            and descenders (1234567890 — the 3, 4, 5, 7, 9 dip below the \
            baseline). Stylish in serif text; tends to look misaligned in \
            monospace terminals.

              • **Lining** (`lnum`) — uniform-height digits aligned to the \
            cap-height baseline. The "modern" figure style most fonts ship as \
            their default — most fonts use this even without the explicit tag.

            **Default** leaves all four tags off and uses whatever the font \
            ships out of the box.
            """,
            link: URL(string: "https://learn.microsoft.com/en-us/typography/opentype/spec/features_pt#tnum")
        ),

        // MARK: shell-integration-features — per-flag context

        "shell-integration-features (cursor)": Entry(
            title: "cursor — Cursor-shape integration",
            body: """
            Lets your shell switch the cursor shape via terminal escape codes. \
            Vim users see the block / bar / underline change automatically in \
            different modes; some prompts use this to flash a different shape \
            on errors.

            Requires Ghostty's shell integration to be loaded (auto-detected \
            for bash/zsh/fish/elvish by default). Disabling leaves the cursor \
            in whatever shape you set in the Cursor pane.
            """,
            link: URL(string: "https://ghostty.org/docs/config/reference#shell-integration-features")
        ),

        "shell-integration-features (sudo)": Entry(
            title: "sudo — Preserve terminfo through sudo",
            body: """
            Wraps `sudo` so the inner command inherits Ghostty's terminfo \
            entry (`xterm-ghostty`). Without this, sudo often resets `TERM` \
            and unfamiliar terminal features stop working in the elevated \
            session.

            Off by default because it overrides the system `sudo` in subtle \
            ways. Enable if you regularly run sudo and see weird rendering, \
            colors, or keybindings break inside the elevated shell.
            """,
            link: URL(string: "https://ghostty.org/docs/config/reference#shell-integration-features")
        ),

        "shell-integration-features (title)": Entry(
            title: "title — Window title from shell",
            body: """
            Lets the shell update the window/tab title via OSC escape codes — \
            so the title can show your current directory, the running command, \
            or whatever the prompt decides to set.

            On by default. Disable if your prompt is noisy with title updates \
            or you want Ghostty's title to stay fixed.
            """,
            link: URL(string: "https://ghostty.org/docs/config/reference#shell-integration-features")
        ),

        "shell-integration-features (ssh-env)": Entry(
            title: "ssh-env — SSH environment compatibility",
            body: """
            When you SSH into a remote host, Ghostty's shell integration \
            rewrites `TERM` from `xterm-ghostty` (which the remote almost \
            certainly doesn't have installed) to `xterm-256color`, and \
            forwards COLORTERM, TERM_PROGRAM, and TERM_PROGRAM_VERSION.

            Whether the remote actually *accepts* those variables depends on \
            its `sshd_config` `AcceptEnv`. This setting only configures the \
            client side. Available since Ghostty 1.2.0.
            """,
            link: URL(string: "https://ghostty.org/docs/config/reference#shell-integration-features")
        ),

        "shell-integration-features (ssh-terminfo)": Entry(
            title: "ssh-terminfo — Install Ghostty terminfo on remote",
            body: """
            On first SSH connect to a host, copies Ghostty's terminfo entry \
            over and runs `tic` to install it. Subsequent connections then get \
            the real `xterm-ghostty` terminfo instead of the `xterm-256color` \
            fallback.

            Requires write permission on the remote (installs to the user's \
            home dir, no sudo). Off by default to avoid surprising file writes \
            on remote hosts you haven't opted into.
            """,
            link: URL(string: "https://ghostty.org/docs/config/reference#shell-integration-features")
        )
    ]
}
