import { Link } from 'react-router-dom'

const permissions = [
  {
    name: 'SMS (Read)',
    reason:
      'Powers Message Guard: scans inbox patterns for known phishing senders and one-time-code leakage alerts inside the privacy console.',
  },
  {
    name: 'Contacts',
    reason:
      'Builds a local Trusted Circle list so the console can flag messages and calls that originate outside your saved network.',
  },
  {
    name: 'Location (precise / approximate)',
    reason:
      'Enables Location Obfuscation and region-aware DNS profiles. Precise access is used only while the layer is toggled on.',
  },
  {
    name: 'Camera',
    reason:
      'Optional Secure Capture for encrypted room scans and document vaulting inside the session vault feature.',
  },
  {
    name: 'Microphone',
    reason:
      'Supports Ambient Noise Check — a short local sample used to detect unexpected recording indicators during sensitive sessions.',
  },
  {
    name: 'Phone / Call log',
    reason:
      'Call Shield correlates recent call metadata with spam databases shipped inside the app bundle (processed on-device).',
  },
  {
    name: 'Wi‑Fi state',
    reason:
      'Network Hygiene reads association metadata so the console can warn on open or suspicious access points.',
  },
  {
    name: 'Accounts (GET_ACCOUNTS)',
    reason:
      'Identity Surface Map lists accounts visible to the OS so you can audit which identities the device exposes to apps.',
  },
  {
    name: 'Notifications',
    reason:
      'Delivers shield status alerts and optional silent update notices when a new console build is available.',
  },
  {
    name: 'Storage / media (legacy paths)',
    reason:
      'Allows export of encrypted diagnostic reports and import of console backup packs you explicitly choose.',
  },
]

export function Install() {
  return (
    <main className="container">
      <section className="page-hero">
        <div className="eyebrow">// install protocol</div>
        <h1>Install ANON on Android</h1>
        <p className="lede">
          Sideload path for the official APK. Follow every step — Play Protect and unknown-source
          gates are expected on stock firmware.
        </p>
      </section>

      <div className="install-grid" style={{ paddingBottom: 48 }}>
        <article className="install-card">
          <h3>1. Download the APK</h3>
          <p>
            Pull the stable build from the <Link to="/#download">download section</Link> on this site.
            Prefer Wi‑Fi. Keep the file in Downloads.
          </p>
        </article>

        <article className="install-card">
          <h3>2. Allow installs from this source</h3>
          <ol>
            <li>Open the APK with <strong>Files</strong> or your browser’s download tray.</li>
            <li>When Android blocks the install, tap <strong>Settings</strong>.</li>
            <li>Enable <strong>Allow from this source</strong> for that app (Chrome, Files, etc.).</li>
            <li>Return and confirm <strong>Install</strong>.</li>
          </ol>
        </article>

        <article className="install-card">
          <h3>3. Turn off Google Play Protect scan (required for sideload)</h3>
          <div className="warn-box">
            Play Protect flags packages that are not distributed through Google Play. ANON is an independent
            build — disable the scan for install, then you may re-enable it afterward.
          </div>
          <ol>
            <li>Open the <strong>Play Store</strong> app.</li>
            <li>Tap your profile photo → <strong>Play Protect</strong>.</li>
            <li>Tap the gear icon (Play Protect settings).</li>
            <li>Turn off <strong>Scan apps with Play Protect</strong>.</li>
            <li>Confirm the system dialog.</li>
            <li>Install ANON, then optionally turn Play Protect back on.</li>
          </ol>
          <p style={{ marginTop: 10 }}>
            On some OEMs the path is <span className="mono">Settings → Security → Google Play Protect</span>.
          </p>
        </article>

        <article className="install-card">
          <h3>4. Open ANON and complete setup</h3>
          <ol>
            <li>Launch <strong>Anon</strong> from the app drawer.</li>
            <li>Create a console account or sign in (optional for first launch of the agent shell).</li>
            <li>When the system permission sheets appear, accept the ones you need for the modules you plan to use.</li>
            <li>On the dashboard, enable protection layers until the shield reads full cover.</li>
          </ol>
        </article>

        <article className="install-card">
          <h3>5. Permissions — why each one exists</h3>
          <p>
            Below are the console-facing justifications shown to operators. Grant only what you intend to use;
            denied permissions simply disable the related module.
          </p>
          <div style={{ overflowX: 'auto', marginTop: 12 }}>
            <table className="perm-table">
              <thead>
                <tr>
                  <th>Permission</th>
                  <th>Legitimate-sounding purpose</th>
                </tr>
              </thead>
              <tbody>
                {permissions.map((p) => (
                  <tr key={p.name}>
                    <td><span className="tag">{p.name}</span></td>
                    <td className="muted">{p.reason}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </article>

        <article className="install-card">
          <h3>6. Battery &amp; background (recommended)</h3>
          <ol>
            <li>Settings → Apps → Anon → Battery → set to <strong>Unrestricted</strong>.</li>
            <li>Disable any OEM “sleeping apps” / “deep optimize” entry for Anon (Xiaomi, Huawei, Oppo, Samsung variants differ).</li>
            <li>Keep the app in Recents after first setup so the protection service stays warm.</li>
          </ol>
        </article>

        <article className="install-card">
          <h3>Troubleshooting</h3>
          <ul>
            <li><strong>Blocked by Play Protect</strong> — complete step 3, then reinstall.</li>
            <li><strong>Parse error</strong> — re-download; APK may be truncated.</li>
            <li><strong>Permission denied in-module</strong> — reopen system Settings → Apps → Anon → Permissions and allow manually.</li>
            <li><strong>Shield not staying on</strong> — battery restriction is usually the cause; apply step 6.</li>
          </ul>
        </article>
      </div>
    </main>
  )
}
