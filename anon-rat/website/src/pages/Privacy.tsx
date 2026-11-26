export function Privacy() {
  return (
    <main className="container" style={{ padding: '48px 0 64px', maxWidth: 760 }}>
      <div className="eyebrow">// privacy</div>
      <h1>Privacy Policy</h1>
      <p className="muted">Last updated: 26 November 2026</p>
      <p>
        ANON provides an Android privacy console. If you register, we store the email and credentials
        required for authentication. Protection toggles and local diagnostics remain on-device unless you
        explicitly enable sync features in a future build.
      </p>
      <p>
        We do not sell personal information to advertisers. Network requests from the console are limited to
        authentication, update checks, and optional cloud features you opt into.
      </p>
      <p>Contact: privacy@anon.example</p>
    </main>
  )
}
