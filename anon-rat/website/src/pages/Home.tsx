import { Link } from 'react-router-dom'
import { features } from '../data/features'

const APK_URL = 'https://example.com/downloads/anon-3.0.0.apk'

export function Home() {
  return (
    <main>
      <section className="container hero">
        <div>
          <div className="eyebrow">// closed circle · android console</div>
          <h1>
            Less signal.<br />
            <span>More control.</span>
          </h1>
          <p className="lede">
            ANON is a polished privacy console for operators who prefer sideloaded builds
            over storefront noise. Cloak device fingerprints, harden DNS, and keep a clean
            shield status on-device.
          </p>
          <div className="hero-cta">
            <a className="btn" href="#download">Download APK</a>
            <Link className="btn btn-ghost" to="/install">Install guide</Link>
          </div>
          <div className="trust">
            <span>v3.0.0</span>
            <span>Android 8.0+</span>
            <span>offline-first UI</span>
            <span>no Play dependency</span>
          </div>
        </div>
        <div className="hero-visual">
          <img src="/brand/hero.jpg" alt="ANON shield visual" />
          <div className="hero-badge">STATUS · SHIELD READY</div>
        </div>
      </section>

      <section id="features" className="section">
        <div className="container">
          <div className="section-head">
            <h2>Modules inside the console</h2>
            <p>Each tile is a consumer-facing protection story — the product surface the victim sees.</p>
          </div>
          <div className="feature-grid">
            {features.map((f) => (
              <article className="feature-card" key={f.id}>
                <img src={f.image} alt={f.title} loading="lazy" />
                <div className="body">
                  <h3>{f.title}</h3>
                  <p>{f.blurb}</p>
                </div>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="section" style={{ paddingTop: 0 }}>
        <div className="container">
          <div className="section-head">
            <h2>Operational path</h2>
            <p>From download to shield-active in four moves.</p>
          </div>
          <div className="steps">
            {[
              ['01', 'Pull the APK', 'Grab the stable build from this node. Hash published with each release.'],
              ['02', 'Disable Play Protect scan', 'Required for sideloaded packages outside the Play catalog — full steps on the install page.'],
              ['03', 'Grant listed permissions', 'Every permission maps to a stated console feature. No silent extras.'],
              ['04', 'Toggle protection layers', 'Open the dashboard and bring the score to full cover.'],
            ].map(([n, t, d]) => (
              <div className="step" key={n}>
                <div className="step-num">{n}</div>
                <div>
                  <strong>{t}</strong>
                  <p className="muted" style={{ margin: '4px 0 0' }}>{d}</p>
                </div>
              </div>
            ))}
          </div>
          <div style={{ textAlign: 'center', marginTop: 22 }}>
            <Link className="btn btn-ghost" to="/install">Open full install walkthrough</Link>
          </div>
        </div>
      </section>

      <section id="download" className="section">
        <div className="container">
          <div className="download-box">
            <div>
              <h2 style={{ margin: '0 0 6px' }}>Download ANON for Android</h2>
              <p className="muted" style={{ margin: 0 }}>Stable channel · universal APK · signed release build</p>
              <div className="meta">
                <span>version 3.0.0</span>
                <span>~28 MB</span>
                <span>API 26+</span>
              </div>
            </div>
            <div>
              <a className="btn" href={APK_URL}>Download APK</a>
              <p className="muted" style={{ fontSize: 12, marginTop: 10, maxWidth: 280 }}>
                Placeholder URL — replace <code className="mono">APK_URL</code> in <code className="mono">Home.tsx</code> before launch.
              </p>
            </div>
          </div>
        </div>
      </section>
    </main>
  )
}
